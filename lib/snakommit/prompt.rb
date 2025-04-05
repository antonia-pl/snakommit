# frozen_string_literal: true

require 'tty-prompt'
require 'tty-spinner'
require 'tty-screen'
require 'pastel'

module Snakommit
  # Handles interactive prompts
  class Prompt
    class PromptError < StandardError; end
    
    BANNER = "SNAKOMMIT - A commit manager"
    
    def initialize
      @config = Config.load
      @git = Git.new
      @tty_prompt = TTY::Prompt.new
      @templates = Templates.new
      @batch_processor = Performance::BatchProcessor.new(20) # Batch size optimized for file operations
      @monitor = Performance::Monitor.new # Performance monitoring
      validate_config
      @pastel = Pastel.new
      @width = TTY::Screen.width > 100 ? 100 : TTY::Screen.width
    rescue => e
      raise PromptError, "Failed to initialize prompt: #{e.message}"
    end

    # Main interactive commit flow
    def commit_flow
      return { error: 'Not in a Git repository' } unless Git.in_repo?

      loop do
        puts @pastel.cyan(BANNER)
        puts "=" * BANNER.length
        
        # Get repository status
        repo_status = @monitor.measure(:repository_status) do
          { unstaged: @git.unstaged_files, untracked: @git.untracked_files, staged: @git.staged_files }
        end
        
        unstaged, untracked, staged = repo_status.values_at(:unstaged, :untracked, :staged)
        
        # Exit if no changes detected
        if unstaged.empty? && untracked.empty? && staged.empty?
          return { error: 'No changes detected in the repository' }
        end
        
        # Show file status
        puts "\nRepository status:"
        puts "- #{staged.length} file(s) staged for commit"
        puts "- #{unstaged.length} file(s) modified but not staged"
        puts "- #{untracked.length} untracked file(s)"
        
        if ENV['SNAKOMMIT_DEBUG']
          puts "\nPerformance report:"
          @monitor.report.each { |line| puts "  #{line}" }
        end
        
        # Handle saved selections
        saved_selections = @git.get_saved_selections
        if saved_selections&.any?
          puts "\nFound selections from a previous session."
          if @tty_prompt.yes?("Would you like to use your previous file selections?", default: true)
            stage_files(@git, saved_selections)
          else
            @git.clear_saved_selections
            select_files(@git)
          end
        else
          select_files(@git)
        end
        
        # Check if any files are staged
        current_staged = @git.staged_files
        if current_staged.empty?
          puts "\n#{@pastel.red('Error:')} No changes staged for commit. Please select files to commit."
          next if @tty_prompt.yes?("Do you want to select files again?", default: true)
          return { error: 'No changes staged for commit. Please select files to commit.' }
        end

        puts "\n" + "-" * 40
        
        # Get commit info
        commit_info = @monitor.measure(:get_commit_info) { get_commit_info }
        
        if commit_info[:error]
          if commit_info[:error] == 'Commit aborted'
            current_staged = @git.staged_files
            if current_staged.any?
              puts "\nThere are still #{current_staged.length} file(s) staged."
              
              if @tty_prompt.yes?("Do you want to continue with these staged files?", default: true)
                next
              elsif @tty_prompt.yes?("Do you want to unstage all files?", default: false)
                unstage_files(@git, current_staged)
                puts "All files have been unstaged."
                next
              else
                return commit_info
              end
            else
              next if @tty_prompt.yes?("Do you want to start over?", default: true)
              return commit_info
            end
          else
            return commit_info
          end
        end

        # Format and preview commit message
        message = format_commit_message(commit_info)
        
        puts "\nFiles to be committed:"
        @git.staged_files.each { |file| puts "- #{file}" }
        
        puts "\nCommit message preview:"
        puts "-" * 40
        puts message
        puts "-" * 40
        
        unless @tty_prompt.yes?('Do you want to proceed with this commit?', default: true)
          next if @tty_prompt.yes?("Do you want to start over?", default: true)
          return { error: 'Commit aborted by user' }
        end
        
        # Perform commit
        spinner = TTY::Spinner.new("[:spinner] Committing changes... ", format: :dots)
        spinner.auto_spin
        
        @monitor.measure(:git_commit) { @git.commit(message) }
        
        spinner.success("Changes committed successfully!")
        puts "\n✓ Successfully committed: #{message.split("\n").first}"
        
        if ENV['SNAKOMMIT_DEBUG']
          puts "\nFinal performance report:"
          @monitor.report.each { |line| puts "  #{line}" }
        end
        
        return { success: true, message: message }
      end
    rescue PromptError => e
      puts "\n#{@pastel.red('Error:')} #{e.message}"
      { error: e.message }
    rescue TTY::Reader::InputInterrupt
      puts "\nCommit process interrupted by user."
      { error: 'Commit aborted by user' }
    rescue Git::GitError => e
      puts "\nError: #{e.message}"
      { error: "Git error: #{e.message}" }
    rescue => e
      puts "\nError: #{e.message}"
      { error: "Error during commit flow: #{e.message}" }
    end

    private

    # Select files to add
    def select_files(git)
      begin
        repo_status = @monitor.measure(:get_files_for_selection) do
          { unstaged: git.unstaged_files, untracked: git.untracked_files, staged: git.staged_files }
        end
        
        unstaged, untracked, staged = repo_status.values_at(:unstaged, :untracked, :staged)
        all_stageable_files = unstaged + untracked
        
        # No files to work with
        if all_stageable_files.empty? && staged.empty?
          puts "No changes detected in the repository."
          return
        end
        
        # Only staged files present
        if all_stageable_files.empty? && staged.any?
          puts "\nCurrently staged files:"
          staged.each { |file| puts "- #{file}" }
          
          unstage_files(git, staged) if @tty_prompt.yes?("Do you want to unstage any files?", default: false)
          return
        end
        
        # Show currently staged files
        unless staged.empty?
          puts "\nCurrently staged files:"
          staged.each { |file| puts "- #{file}" }
        end
        
        # Build options for file selection
        options = []
        options << { name: "[ ALL FILES ]", value: :all_files } if all_stageable_files.any?
        
        unstaged.each_with_index do |file, idx|
          options << { name: "#{idx+1}. Modified: #{file}", value: file }
        end
        
        untracked.each_with_index do |file, idx|
          options << { name: "#{unstaged.length + idx + 1}. Untracked: #{file}", value: file }
        end
        
        if options.empty?
          puts "No files available to stage."
          return
        end
        
        # Get user selections
        puts "\nSelect files to stage for commit:"
        selected = @tty_prompt.multi_select("Choose files (use space to select, enter to confirm):", options, per_page: 15, echo: true)
        
        # Handle no selection
        if selected.empty?
          puts "No files selected for staging."
          
          unless staged.empty?
            puts "You already have #{staged.length} file(s) staged."
            return select_files(git) if @tty_prompt.yes?("Do you want to select files again?", default: true)
          end
          
          return
        end
        
        # Process selection
        puts "\nSelected files to stage:"
        
        if selected.include?(:all_files)
          selected = all_stageable_files
          puts "- All files (#{selected.length})"
        else
          selected.each { |file| puts "- #{file}" }
        end
        
        # Confirm and stage
        if @tty_prompt.yes?("Proceed with staging these files?", default: true)
          stage_files(git, selected)
        else
          puts "Staging canceled by user."
          return
        end
        
        # Offer to unstage
        newly_staged = git.staged_files
        if newly_staged.any? && @tty_prompt.yes?("Do you want to unstage any files?", default: false)
          unstage_files(git, newly_staged)
        end
      rescue TTY::Reader::InputInterrupt
        puts "\nFile selection interrupted."
        
        # Ask the user if they want to continue or abort
        begin
          unless @tty_prompt.yes?("Do you want to continue with the commit process?", default: false)
            puts "Commit process aborted by user."
            raise PromptError, "Commit aborted by user"
          end
        rescue TTY::Reader::InputInterrupt
          puts "\nCommit process aborted."
          raise PromptError, "Commit aborted by user"
        end
        
        return
      rescue => e
        puts "\nError during file selection: #{e.message}"
        puts "Would you like to try again?"
        return if @tty_prompt.yes?("Try selecting files again?", default: true)
        raise PromptError, "Failed to select files: #{e.message}"
      end
    end
    
    # Stage the selected files
    def stage_files(git, selected)
      # Save the selections for future use
      git.save_selections(selected)
      
      spinner = TTY::Spinner.new("[:spinner] Adding files... ", format: :dots)
      spinner.auto_spin
      
      # Use batch processing for more efficient staging
      @monitor.measure(:batch_stage_files) do
        @batch_processor.process_files(selected) do |batch|
          # Use parallel helper if available and appropriate
          Performance::ParallelHelper.process(batch, threshold: 5) do |file|
            git.add(file)
          end
        end
      end
      
      # Verify staging worked
      newly_staged = git.staged_files
      if newly_staged.empty?
        spinner.error("Failed to stage files!")
        puts "Warning: No files appear to be staged after add operation."
        puts "This might be a Git or permission issue."
        raise PromptError, "Failed to stage files"
      else
        spinner.success("Files added to staging area (#{newly_staged.length} file(s))")
      end
    rescue => e
      raise PromptError, "Failed to stage files: #{e.message}"
    end
    
    # Unstage selected files
    def unstage_files(git, staged_files)
      return if staged_files.empty?
      
      unstage_options = staged_files.map { |f| { name: f, value: f } }
      puts "\nUnstage Files:"
      
      begin
        to_unstage = @tty_prompt.multi_select("Select files to unstage:", unstage_options, per_page: 15)
        
        unless to_unstage.empty?
          spinner = TTY::Spinner.new("[:spinner] Unstaging files... ", format: :dots)
          spinner.auto_spin
          
          @monitor.measure(:batch_unstage_files) do
            @batch_processor.process_files(to_unstage) do |batch|
              batch.each { |file| git.reset(file) }
            end
          end
          
          spinner.success("Files unstaged")
          
          # Check if all files unstaged
          remaining_staged = git.staged_files
          if remaining_staged.empty?
            puts "#{@pastel.yellow('Note:')} All files have been unstaged."
            
            # Offer to select new files if available
            unstaged_files = git.unstaged_files
            untracked_files = git.untracked_files
            
            if (unstaged_files + untracked_files).any?
              begin
                if @tty_prompt.yes?("Do you want to select new files now?", default: true)
                  select_files(git)
                end
              rescue Interrupt
                puts "\nFile selection interrupted."
              end
            end
          end
        end
      rescue TTY::Reader::InputInterrupt
        puts "\nUnstaging files aborted."
      rescue => e
        raise PromptError, "Failed to unstage files: #{e.message}"
      end
    end

    # Get commit information
    def get_commit_info
      info = {}
      
      puts "\nCommit Details:"
      
      info[:type] = select_type
      
      # Handle scope selection
      suggested_scopes = @config['scopes']
      if suggested_scopes&.any?
        scope_options = suggested_scopes.map { |s| { name: s, value: s } }
        scope_options << { name: '[none]', value: nil }
        
        info[:scope] = @tty_prompt.select('Select the scope of this change (optional, press Enter to skip):', 
                                    scope_options,
                                    per_page: 10)
      else
        info[:scope] = @tty_prompt.ask('Enter the scope of this change (optional, press Enter to skip):')
      end
      
      # Get subject
      info[:subject] = @tty_prompt.ask('Enter a short description:') do |q|
        q.required true
        q.validate(/^.{1,#{@config['max_subject_length']}}$/, "Subject must be less than #{@config['max_subject_length']} characters")
      end
      
      # Get body text
      puts "Enter a longer description (optional, press Enter to skip):"
      puts "Type your message and press Enter when done. Leave empty to skip."
      
      body_lines = []
      loop do
        line = @tty_prompt.ask("")
        break if line.nil? || line.empty?
        body_lines << line
      end
      
      info[:body] = body_lines
      
      # Breaking changes
      info[:breaking] = @tty_prompt.yes?('Is this a breaking change?', default: false)
      if info[:breaking]
        info[:breaking_description] = @tty_prompt.ask('Enter breaking change description:') do |q|
          q.required true
        end
      end
      
      # Issue references
      if @tty_prompt.yes?('Does this commit close any issues?', default: false)
        info[:issues] = @tty_prompt.ask('Enter issue references (e.g., "fix #123, close #456"):') do |q|
          q.required true
        end
      end
      
      info
    rescue Interrupt
      # Improved interrupt handling
      puts "\n#{@pastel.yellow('Interruption:')} Commit process interrupted."
      
      # Check if there are staged files
      staged_files = @git.staged_files
      if staged_files.any?
        puts "There are currently #{staged_files.length} file(s) staged."
        
        # Offer user to unstage files
        begin
          if @tty_prompt.yes?("Do you want to unstage these files?", default: false)
            unstage_files(@git, staged_files)
            puts "All files have been unstaged."
          end
        rescue Interrupt
          puts "\nInterruption detected. Aborting commit process."
        end
      end
      
      { error: 'Commit aborted' }
    rescue => e
      { error: "Failed to gather commit information: #{e.message}" }
    end

    # Format the commit message according to convention
    def format_commit_message(info)
      # Format header (type, scope, subject)
      commit_type = @templates.emoji_enabled? ? @templates.format_commit_type(info[:type]) : info[:type]
      
      header = if info[:scope] && !info[:scope].empty?
                "#{commit_type}(#{info[:scope]}): #{info[:subject]}"
              else
                "#{commit_type}: #{info[:subject]}"
              end
      
      # Format body and additional sections
      body = info[:body].empty? ? '' : "\n\n#{info[:body].join("\n")}"
      breaking = info[:breaking] ? "\n\nBREAKING CHANGE: #{info[:breaking_description]}" : ''
      issues = info[:issues] ? "\n\n#{info[:issues]}" : ''
      
      "#{header}#{body}#{breaking}#{issues}"
    rescue => e
      raise PromptError, "Failed to format commit message: #{e.message}"
    end

    def select_type
      commit_types = @config['types']
      
      choices = commit_types.map do |type|
        value = type['name']
        
        # Format the display name based on emoji settings
        if @templates.emoji_enabled?
          emoji = @templates.get_emoji_for_type(value)
          name = emoji ? "#{emoji} #{value}: #{type['description']}" : "#{value}: #{type['description']}"
        else
          name = "#{value}: #{type['description']}"
        end
        
        { name: name, value: value }
      end
      
      @tty_prompt.select('Choose a type:', choices, filter: true, per_page: 10)
    end

    # Validates the configuration loaded from file
    def validate_config
      unless @config.is_a?(Hash) && @config['types'].is_a?(Array)
        raise PromptError, "Invalid configuration format: 'types' must be an array"
      end
      
      if @config['types'].empty?
        raise PromptError, "Configuration error: No commit types defined"
      end
      
      # Ensure all required keys are present
      @config['max_subject_length'] ||= 100
      @config['max_body_line_length'] ||= 72
      @config['scopes'] ||= []
    end
  end
end 