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

      puts @pastel.cyan(BANNER)
      puts "=" * BANNER.length
      
      # Get the status of the repository with performance monitoring
      repo_status = @monitor.measure(:repository_status) do
        {
          unstaged: @git.unstaged_files,
          untracked: @git.untracked_files,
          staged: @git.staged_files
        }
      end
      
      unstaged = repo_status[:unstaged]
      untracked = repo_status[:untracked]
      staged = repo_status[:staged]
      
      # Check if there are any changes to work with
      if unstaged.empty? && untracked.empty? && staged.empty?
        return { error: 'No changes detected in the repository' }
      end
      
      # Show file status
      puts "\nRepository status:"
      puts "- #{staged.length} file(s) staged for commit"
      puts "- #{unstaged.length} file(s) modified but not staged"
      puts "- #{untracked.length} untracked file(s)"
      
      # Report performance if debug is enabled
      if ENV['SNAKOMMIT_DEBUG']
        puts "\nPerformance report:"
        @monitor.report.each { |line| puts "  #{line}" }
      end
      
      # Check for saved selections from a previous run
      saved_selections = @git.get_saved_selections
      if saved_selections && !saved_selections.empty?
        puts "\nFound selections from a previous session."
        if @tty_prompt.yes?("Would you like to use your previous file selections?", default: true)
          # Stage the previously selected files
          stage_files(@git, saved_selections)
        else
          # If user doesn't want to use previous selections, clear them
          @git.clear_saved_selections
          # Always show file selection to user
          select_files(@git)
        end
      else
        # Always show file selection to user
        select_files(@git)
      end
      
      # Re-check staged files after selection
      current_staged = @git.staged_files
      
      # After file selection, check if we have staged files
      if current_staged.empty?
        return { error: 'No changes staged for commit. Please select files to commit.' }
      end

      # Divider
      puts "\n" + "-" * 40
      
      # Now get the commit info
      commit_info = @monitor.measure(:get_commit_info) do
        get_commit_info
      end
      return commit_info if commit_info[:error]

      # Format the commit message
      message = format_commit_message(commit_info)
      
      # Show which files will be committed
      puts "\nFiles to be committed:"
      staged_for_commit = @git.staged_files
      staged_for_commit.each do |file|
        puts "- #{file}"
      end
      
      # Preview the commit message
      puts "\nCommit message preview:"
      puts "-" * 40
      puts message
      puts "-" * 40
      
      # Confirm the commit
      return { error: 'Commit aborted by user' } unless @tty_prompt.yes?('Do you want to proceed with this commit?', default: true)
      
      # Commit the changes
      spinner = TTY::Spinner.new("[:spinner] Committing changes... ", format: :dots)
      spinner.auto_spin
      
      @monitor.measure(:git_commit) do
        @git.commit(message)
      end
      
      spinner.success("Changes committed successfully!")
      
      # Final success message
      puts "\n✓ Successfully committed: #{message.split("\n").first}"
      
      # Show performance stats in debug mode
      if ENV['SNAKOMMIT_DEBUG']
        puts "\nFinal performance report:"
        @monitor.report.each { |line| puts "  #{line}" }
      end
      
      { success: true, message: message }
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
        # Get file lists with performance monitoring
        repo_status = @monitor.measure(:get_files_for_selection) do
          {
            unstaged: git.unstaged_files,
            untracked: git.untracked_files,
            staged: git.staged_files
          }
        end
        
        unstaged = repo_status[:unstaged]
        untracked = repo_status[:untracked]
        staged = repo_status[:staged]
        
        # Combine all files that could be staged
        all_stageable_files = unstaged + untracked
        
        # If there are no files to stage or unstage, return early
        if all_stageable_files.empty? && staged.empty?
          puts "No changes detected in the repository."
          return
        end
        
        # If we only have staged files but nothing new to stage
        if all_stageable_files.empty? && !staged.empty?
          puts "\nCurrently staged files:"
          staged.each { |file| puts "- #{file}" }
          
          # Ask if user wants to unstage any files
          if @tty_prompt.yes?("Do you want to unstage any files?", default: false)
            unstage_files(git, staged)
          end
          return
        end
        
        # First show the user what's currently staged
        unless staged.empty?
          puts "\nCurrently staged files:"
          staged.each { |file| puts "- #{file}" }
        end
        
        # Create options for the file selection menu
        options = []
        
        # Add "ALL FILES" option at the top if we have unstaged or untracked files
        if !all_stageable_files.empty?
          options << { name: "[ ALL FILES ]", value: :all_files }
        end
        
        # Add modified files with index numbers
        unstaged.each_with_index do |file, idx|
          options << { name: "#{idx+1}. Modified: #{file}", value: file }
        end
        
        # Add untracked files with continuing index numbers
        untracked.each_with_index do |file, idx|
          options << { name: "#{unstaged.length + idx + 1}. Untracked: #{file}", value: file }
        end
        
        # Skip if no options
        if options.empty?
          puts "No files available to stage."
          return
        end
        
        # Prompt user to select files
        puts "\nSelect files to stage for commit:"
        selected = @tty_prompt.multi_select("Choose files (use space to select, enter to confirm):", options, per_page: 15, echo: true)
        
        # Check if anything was selected
        if selected.empty?
          puts "No files selected for staging."
          
          # If we already have staged files, ask if user wants to continue with those
          unless staged.empty?
            puts "You already have #{staged.length} file(s) staged."
            return unless @tty_prompt.yes?("Do you want to select files again?", default: true)
            return select_files(git)  # Recursive call to try again
          end
          
          return
        end
        
        puts "\nSelected files to stage:"
        
        # Handle "ALL FILES" option
        if selected.include?(:all_files)
          selected = all_stageable_files
          puts "- All files (#{selected.length})"
        else
          selected.each { |file| puts "- #{file}" }
        end
        
        # Add a confirmation step
        if @tty_prompt.yes?("Proceed with staging these files?", default: true)
          # Stage the selected files
          stage_files(git, selected)
        else
          puts "Staging canceled by user."
          return
        end
        
        # After staging, check if the user wants to unstage any files
        newly_staged = git.staged_files
        unless newly_staged.empty?
          if @tty_prompt.yes?("Do you want to unstage any files?", default: false)
            unstage_files(git, newly_staged)
          end
        end
      rescue TTY::Reader::InputInterrupt
        puts "\nFile selection aborted. Press Ctrl+C again to exit completely or continue."
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
      
      # Create options for unstaging
      unstage_options = staged_files.map { |f| { name: f, value: f } }
      
      # Unstage heading
      puts "\nUnstage Files:"
      
      # Select files to unstage
      to_unstage = @tty_prompt.multi_select("Select files to unstage:", unstage_options, per_page: 15)
      
      unless to_unstage.empty?
        spinner = TTY::Spinner.new("[:spinner] Unstaging files... ", format: :dots)
        spinner.auto_spin
        
        # Use batch processing for more efficient unstaging
        @monitor.measure(:batch_unstage_files) do
          @batch_processor.process_files(to_unstage) do |batch|
            batch.each { |file| git.reset(file) }
          end
        end
        
        spinner.success("Files unstaged")
      end
    rescue => e
      raise PromptError, "Failed to unstage files: #{e.message}"
    end

    # Get commit information
    def get_commit_info
      info = {}
      
      puts "\nCommit Details:"
      
      # Select commit type
      info[:type] = select_type
      
      # Enter scope (optional)
      suggested_scopes = @config['scopes']
      if suggested_scopes && !suggested_scopes.empty?
        scope_options = suggested_scopes.map { |s| { name: s, value: s } }
        scope_options << { name: '[none]', value: nil }
        
        info[:scope] = @tty_prompt.select('Select the scope of this change (optional, press Enter to skip):', 
                                    scope_options,
                                    per_page: 10)
      else
        info[:scope] = @tty_prompt.ask('Enter the scope of this change (optional, press Enter to skip):')
      end
      
      # Enter subject
      info[:subject] = @tty_prompt.ask('Enter a short description:') do |q|
        q.required true
        q.validate(/^.{1,#{@config['max_subject_length']}}$/, "Subject must be less than #{@config['max_subject_length']} characters")
      end
      
      # Enter longer description (optional)
      puts "Enter a longer description (optional, press Enter to skip):"
      puts "Type your message and press Enter when done. Leave empty to skip."
      
      body_lines = []
      # Read input until an empty line is entered
      loop do
        line = @tty_prompt.ask("")
        break if line.nil? || line.empty?
        body_lines << line
      end
      
      info[:body] = body_lines
      
      # Is this a breaking change?
      info[:breaking] = @tty_prompt.yes?('Is this a breaking change?', default: false)
      
      # Breaking change description
      if info[:breaking]
        info[:breaking_description] = @tty_prompt.ask('Enter breaking change description:') do |q|
          q.required true
        end
      end
      
      # Any issues closed?
      if @tty_prompt.yes?('Does this commit close any issues?', default: false)
        info[:issues] = @tty_prompt.ask('Enter issue references (e.g., "fix #123, close #456"):') do |q|
          q.required true
        end
      end
      
      info
    rescue Interrupt
      { error: 'Commit aborted' }
    rescue => e
      { error: "Failed to gather commit information: #{e.message}" }
    end

    # Format the commit message according to convention
    def format_commit_message(info)
      begin
        header = ''
        
        # Format the type and scope
        commit_type = @templates.emoji_enabled? ? @templates.format_commit_type(info[:type]) : info[:type]
        
        if info[:scope] && !info[:scope].empty?
          header = "#{commit_type}(#{info[:scope]}): #{info[:subject]}"
        else
          header = "#{commit_type}: #{info[:subject]}"
        end
        
        # Format the body
        body = info[:body].empty? ? '' : "\n\n#{info[:body].join("\n")}"
        
        # Format breaking change
        breaking = ''
        if info[:breaking]
          breaking = "\n\nBREAKING CHANGE: #{info[:breaking_description]}"
        end
        
        # Format issues
        issues = info[:issues] ? "\n\n#{info[:issues]}" : ''
        
        # Return the full commit message
        message = "#{header}#{body}#{breaking}#{issues}"
        
        message
      rescue => e
        raise PromptError, "Failed to format commit message: #{e.message}"
      end
    end

    def select_type
      commit_types = @config['types']
      
      choices = commit_types.map do |type|
        value = type['name']
        
        # Format the display name based on emoji settings
        if @templates.emoji_enabled?
          emoji = @templates.get_emoji_for_type(value)
          # Ensure there's a space between emoji and type
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