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

    # Stage the specified files
    def add(files)
      @repo.add(files)
      true
    rescue => e
      raise GitError, "Failed to add files: #{e.message}"
    end

    # Commit with the given message
    def commit(message)
      @repo.commit(message)
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