# frozen_string_literal: true

require 'tty-prompt'
require 'tty-spinner'

module Snakommit
  # Handles interactive prompts
  class Prompt
    def initialize
      @prompt = TTY::Prompt.new
      @config = Config.load
    end

    # Main interactive commit flow
    def commit_flow
      return { error: 'Not in a Git repository' } unless Git.in_repo?

      git = Git.new
      
      # Check for changes before proceeding
      if git.staged_files.empty? && git.unstaged_files.empty? && git.untracked_files.empty?
        return { error: 'No changes to commit' }
      end

      # If there are unstaged or untracked files, prompt to add them
      select_files(git) if git.staged_files.empty?

      # Now get the commit info
      commit_info = get_commit_info
      return commit_info if commit_info[:error]

      # Format the commit message
      message = format_commit_message(commit_info)
      
      # Commit the changes
      git.commit(message)
      
      { success: true, message: message }
    end

    private

    # Select files to add
    def select_files(git)
      unstaged = git.unstaged_files
      untracked = git.untracked_files
      
      return if unstaged.empty? && untracked.empty?

      files = []
      files += unstaged.map { |f| { name: "Modified: #{f}", value: f } } unless unstaged.empty?
      files += untracked.map { |f| { name: "Untracked: #{f}", value: f } } unless untracked.empty?

      selected = @prompt.multi_select('Select files to stage:', files, per_page: 15)
      
      unless selected.empty?
        spinner = TTY::Spinner.new("[:spinner] Adding files ...", format: :dots)
        spinner.auto_spin
        git.add(selected)
        spinner.success("Files added")
      end
    end

    # Get commit information
    def get_commit_info
      info = {}
      
      # Select commit type
      types = @config['types'].map { |t| { name: "#{t['name']}: #{t['description']}", value: t['name'] } }
      info[:type] = @prompt.select('Select the type of change you\'re committing:', types, per_page: 10)
      
      # Enter scope (optional)
      suggested_scopes = @config['scopes']
      if suggested_scopes && !suggested_scopes.empty?
        info[:scope] = @prompt.select('Select the scope of this change (optional, press Enter to skip):', 
                                    suggested_scopes.map { |s| { name: s, value: s } } << { name: '[none]', value: nil },
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
      info[:body] = @prompt.multiline('Enter a longer description (optional, press Enter to skip):')
      
      # Is this a breaking change?
      info[:breaking] = @prompt.yes?('Is this a breaking change?')
      
      # Breaking change description
      if info[:breaking]
        info[:breaking_description] = @prompt.ask('Enter breaking change description:') do |q|
          q.required true
        end
      end
      
      # Any issues closed?
      if @prompt.yes?('Does this commit close any issues?')
        info[:issues] = @prompt.ask('Enter issue references (e.g., "fix #123, close #456"):') do |q|
          q.required true
        end
      end
      
      info
    rescue Interrupt
      { error: 'Commit aborted' }
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
    end
  end
end 