# frozen_string_literal: true

require 'git'
require 'open3'

module Snakommit
  # Handles Git operations
  class Git
    class GitError < StandardError; end

    def initialize(path = Dir.pwd)
      @path = path
      @repo = ::Git.open(path)
    rescue ArgumentError => e
      raise GitError, "Failed to open Git repository: #{e.message}"
    end

    # Get the list of staged files
    def staged_files
      stdout, stderr, status = Open3.capture3('git', 'diff', '--name-only', '--cached')
      raise GitError, "Git error: #{stderr}" unless status.success?

      stdout.split("\n")
    end

    # Get the list of modified but unstaged files
    def unstaged_files
      stdout, stderr, status = Open3.capture3('git', 'diff', '--name-only')
      raise GitError, "Git error: #{stderr}" unless status.success?

      stdout.split("\n")
    end

    # Get the list of untracked files
    def untracked_files
      stdout, stderr, status = Open3.capture3('git', 'ls-files', '--others', '--exclude-standard')
      raise GitError, "Git error: #{stderr}" unless status.success?

      stdout.split("\n")
    end

    # Stage the specified files - using direct command for better reliability
    def add(files)
      return true if files.empty?
      
      # Make sure files is an array
      files_to_add = files.is_a?(Array) ? files : [files]
      
      # Debug output
      puts "Staging #{files_to_add.length} file(s):"
      files_to_add.each { |f| puts "  Adding: #{f}" }
      
      stdout, stderr, status = Open3.capture3('git', 'add', *files_to_add)
      raise GitError, "Failed to add files: #{stderr}" unless status.success?
      
      # Verify the files were added
      newly_staged = staged_files
      puts "Successfully staged #{newly_staged.length} file(s)"
      true
    rescue => e
      raise GitError, "Failed to add files: #{e.message}"
    end

    # Unstage the specified files
    def reset(files)
      return true if files.empty?
      
      files_to_reset = files.is_a?(Array) ? files : [files]
      
      stdout, stderr, status = Open3.capture3('git', 'reset', 'HEAD', *files_to_reset)
      raise GitError, "Failed to unstage files: #{stderr}" unless status.success?
      
      true
    rescue => e
      raise GitError, "Failed to unstage files: #{e.message}"
    end

    # Commit with the given message
    def commit(message)
      # Create temporary file for commit message to avoid shell escaping issues
      message_file = File.join(@path, '.git', 'COMMIT_EDITMSG')
      File.write(message_file, message)
      
      stdout, stderr, status = Open3.capture3('git', 'commit', '-F', message_file)
      
      # Clean up temp file
      File.unlink(message_file) if File.exist?(message_file)
      
      raise GitError, "Failed to commit: #{stderr}" unless status.success?
      true
    rescue => e
      raise GitError, "Failed to commit: #{e.message}"
    end

    # Check if we're in a git repository
    def self.in_repo?(path = Dir.pwd)
      ::Git.open(path)
      true
    rescue
      false
    end
  end
end 