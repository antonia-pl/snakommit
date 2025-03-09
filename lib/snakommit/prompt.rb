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
      @prompt = TTY::Prompt.new
      @config = Config.load
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
      
      git = Git.new
      
      # Get the status of the repository
      unstaged = git.unstaged_files
      untracked = git.untracked_files
      staged = git.staged_files
      
      # Check if there are any changes to work with
      if unstaged.empty? && untracked.empty? && staged.empty?
        return { error: 'No changes detected in the repository' }
      end
      
      # Show file status
      puts "\nRepository status:"
      puts "- #{staged.length} file(s) staged for commit"
      puts "- #{unstaged.length} file(s) modified but not staged"
      puts "- #{untracked.length} untracked file(s)"
      
      # Always show file selection to user
      select_files(git)
      
      # Re-check staged files after selection
      current_staged = git.staged_files
      
      # After file selection, check if we have staged files
      if current_staged.empty?
        return { error: 'No changes staged for commit. Please select files to commit.' }
      end

      # Divider
      puts "\n" + "-" * 40
      
      # Now get the commit info
      commit_info = get_commit_info
      return commit_info if commit_info[:error]

      # Format the commit message
      message = format_commit_message(commit_info)
      
      # Show which files will be committed
      puts "\nFiles to be committed:"
      staged_for_commit = git.staged_files
      staged_for_commit.each do |file|
        puts "- #{file}"
      end
      
      # Preview the commit message
      puts "\nCommit message preview:"
      puts "-" * 40
      puts message
      puts "-" * 40
      
      # Confirm the commit
      return { error: 'Commit aborted by user' } unless @prompt.yes?('Do you want to proceed with this commit?', default: true)
      
      # Commit the changes
      spinner = TTY::Spinner.new("[:spinner] Committing changes... ", format: :dots)
      spinner.auto_spin
      git.commit(message)
      spinner.success("Changes committed successfully!")
      
      # Final success message
      puts "\n✓ Successfully committed: #{message.split("\n").first}"
      
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
        # Get file lists
        unstaged = git.unstaged_files
        untracked = git.untracked_files
        staged = git.staged_files
        
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
          if @prompt.yes?("Do you want to unstage any files?", default: false)
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
        selected = @prompt.multi_select("Choose files (use space to select, enter to confirm):", options, per_page: 15, echo: true)
        
        # Check if anything was selected
        if selected.empty?
          puts "No files selected for staging."
          
          # If we already have staged files, ask if user wants to continue with those
          unless staged.empty?
            puts "You already have #{staged.length} file(s) staged."
            return unless @prompt.yes?("Do you want to select files again?", default: true)
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
        if @prompt.yes?("Proceed with staging these files?", default: true)
          # Stage the selected files
          spinner = TTY::Spinner.new("[:spinner] Adding files... ", format: :dots)
          spinner.auto_spin
          
          # Add each file individually
          selected.each do |file|
            git.add(file)
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
        else
          puts "Staging canceled by user."
          return
        end
        
        # After staging, check if the user wants to unstage any files
        newly_staged = git.staged_files
        unless newly_staged.empty?
          if @prompt.yes?("Do you want to unstage any files?", default: false)
            unstage_files(git, newly_staged)
          end
        end
      rescue TTY::Reader::InputInterrupt
        puts "\nFile selection aborted. Press Ctrl+C again to exit completely or continue."
        return
      rescue => e
        puts "\nError during file selection: #{e.message}"
        puts "Would you like to try again?"
        return if @prompt.yes?("Try selecting files again?", default: true)
        raise PromptError, "Failed to select files: #{e.message}"
      end
    end
    
    # Unstage selected files
    def unstage_files(git, staged_files)
      return if staged_files.empty?
      
      # Create options for unstaging
      unstage_options = staged_files.map { |f| { name: f, value: f } }
      
      # Unstage heading
      puts "\nUnstage Files:"
      
      # Select files to unstage
      to_unstage = @prompt.multi_select("Select files to unstage:", unstage_options, per_page: 15)
      
      unless to_unstage.empty?
        spinner = TTY::Spinner.new("[:spinner] Unstaging files... ", format: :dots)
        spinner.auto_spin
        git.reset(to_unstage)
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
      types = @config['types'].map { |t| { name: "#{t['name']}: #{t['description']}", value: t['name'] } }
      
      info[:type] = @prompt.select('Select the type of change you\'re committing:', types, per_page: 10)
      
      # Enter scope (optional)
      suggested_scopes = @config['scopes']
      if suggested_scopes && !suggested_scopes.empty?
        scope_options = suggested_scopes.map { |s| { name: s, value: s } }
        scope_options << { name: '[none]', value: nil }
        
        info[:scope] = @prompt.select('Select the scope of this change (optional, press Enter to skip):', 
                                    scope_options,
                                    per_page: 10)
      else
        info[:scope] = @prompt.ask('Enter the scope of this change (optional, press Enter to skip):')
      end
      
      # Enter subject
      info[:subject] = @prompt.ask('Enter a short description:') do |q|
        q.required true
        q.validate(/^.{1,#{@config['max_subject_length']}}$/, "Subject must be less than #{@config['max_subject_length']} characters")
      end
      
      # Enter longer description (optional)
      puts "Enter a longer description (optional, press Enter to skip):"
      puts "Type your message and press Enter when done. Leave empty to skip."
      
      body_lines = []
      # Read input until an empty line is entered
      loop do
        line = @prompt.ask("")
        break if line.nil? || line.empty?
        body_lines << line
      end
      
      info[:body] = body_lines
      
      # Is this a breaking change?
      info[:breaking] = @prompt.yes?('Is this a breaking change?', default: false)
      
      # Breaking change description
      if info[:breaking]
        info[:breaking_description] = @prompt.ask('Enter breaking change description:') do |q|
          q.required true
        end
      end
      
      # Any issues closed?
      if @prompt.yes?('Does this commit close any issues?', default: false)
        info[:issues] = @prompt.ask('Enter issue references (e.g., "fix #123, close #456"):') do |q|
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
      # Format the first line: <type>(<scope>): <subject>
      header = info[:type].to_s.strip
      header += "(#{info[:scope]})" if info[:scope] && !info[:scope].empty?
      header += ": #{info[:subject]}"
      
      # Add the body if present
      body = ""
      if info[:body] && !info[:body].empty?
        # Wrap the body text to max_body_line_length
        wrapped_body = info[:body].join("\n")
        body = "\n\n#{wrapped_body}"
      end
      
      # Add breaking change marker
      if info[:breaking]
        body += "\n\nBREAKING CHANGE: #{info[:breaking_description]}"
      end
      
      # Add issue references
      if info[:issues] && !info[:issues].empty?
        body += "\n\n#{info[:issues]}"
      end
      
      header + body
    rescue => e
      raise PromptError, "Failed to format commit message: #{e.message}"
    end
  end
end 