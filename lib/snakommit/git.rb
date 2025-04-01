# frozen_string_literal: true

require 'git'
require 'open3'
require 'json'
require 'fileutils'
require 'singleton'

module Snakommit
  # Git operations handler
  class Git
    class GitError < StandardError; end
    
    # Process pool for executing Git commands
    class CommandPool
      include Singleton
      
      def initialize
        @mutex = Mutex.new
        @command_cache = {}
      end
      
      # Execute a command with caching for identical commands
      # @param command [String] Command to execute
      # @return [String] Command output
      def execute(command)
        # Return from cache if available and recent
        @mutex.synchronize do
          if @command_cache[command] && (Time.now - @command_cache[command][:timestamp] < 1)
            return @command_cache[command][:output]
          end
        end
        
        # Execute the command
        stdout, stderr, status = Open3.capture3(command)
        
        unless status.success?
          raise GitError, "Git command failed: #{stderr.strip}"
        end
        
        result = stdout.strip
        
        # Cache the result
        @mutex.synchronize do
          @command_cache[command] = { output: result, timestamp: Time.now }
          
          # Clean cache if it gets too large
          if @command_cache.size > 100
            @command_cache.keys.sort_by { |k| @command_cache[k][:timestamp] }[0...50].each do |k|
              @command_cache.delete(k)
            end
          end
        end
        
        result
      end
    end

    SELECTION_FILE = File.join(Snakommit.config_dir, 'selections.json')
    SELECTION_TTL = 1800 # 30 minutes in seconds
    CACHE_TTL = 5 # 5 seconds for git status cache

    def self.in_repo?
      system('git rev-parse --is-inside-work-tree >/dev/null 2>&1')
    end

    def initialize
      @path = Dir.pwd
      validate_git_repo
      # Initialize cache for performance
      @cache = Performance::Cache.new(50, CACHE_TTL)
    rescue Errno::ENOENT, ArgumentError => e
      raise GitError, "Failed to initialize Git: #{e.message}"
    end

    def staged_files
      @cache.get(:staged_files) || @cache.set(:staged_files, run_command("git diff --name-only --cached").split("\n"))
    end

    def unstaged_files
      @cache.get(:unstaged_files) || @cache.set(:unstaged_files, run_command("git diff --name-only").split("\n"))
    end

    def untracked_files
      @cache.get(:untracked_files) || @cache.set(:untracked_files, run_command("git ls-files --others --exclude-standard").split("\n"))
    end

    def add(file)
      result = run_command("git add -- #{shell_escape(file)}")
      # Invalidate cache since repository state changed
      invalidate_status_cache
      result
    end

    def reset(file)
      result = run_command("git reset HEAD -- #{shell_escape(file)}")
      # Invalidate cache since repository state changed
      invalidate_status_cache
      result
    end

    # Commit with the given message
    def commit(message)
      with_temp_file(message) do |message_file|
        stdout, stderr, status = Open3.capture3('git', 'commit', '-F', message_file)
        
        # Clear any saved selections after successful commit
        clear_saved_selections
        
        unless status.success?
          raise GitError, "Failed to commit: #{stderr.strip}"
        end
        
        # Invalidate cache since repository state changed
        invalidate_status_cache
        true
      end
    end

    # Save selected files to a temporary file
    def save_selections(selected_files)
      return if selected_files.nil? || selected_files.empty?

      repo_path = run_command("git rev-parse --show-toplevel").strip
      data = {
        repo: repo_path,
        selected: selected_files,
        timestamp: Time.now.to_i
      }

      FileUtils.mkdir_p(File.dirname(SELECTION_FILE))
      File.write(SELECTION_FILE, data.to_json)
    rescue => e
      # Silently fail, this is just a convenience feature
      warn "Warning: Failed to save selections: #{e.message}" if ENV['SNAKOMMIT_DEBUG']
    end

    # Get previously selected files if they exist and are recent
    def get_saved_selections
      return nil unless File.exist?(SELECTION_FILE)

      begin
        data = JSON.parse(File.read(SELECTION_FILE))
        repo_path = run_command("git rev-parse --show-toplevel").strip
        
        if valid_selection?(data, repo_path)
          return data['selected']
        end
      rescue => e
        # If there's an error, just ignore the saved selections
        warn "Warning: Failed to load selections: #{e.message}" if ENV['SNAKOMMIT_DEBUG']
      end
      
      nil
    end

    # Clear saved selections
    def clear_saved_selections
      File.delete(SELECTION_FILE) if File.exist?(SELECTION_FILE)
    rescue => e
      # Silently fail
      warn "Warning: Failed to clear selections: #{e.message}" if ENV['SNAKOMMIT_DEBUG']
    end

    private

    def invalidate_status_cache
      @cache.invalidate(:staged_files)
      @cache.invalidate(:unstaged_files)
      @cache.invalidate(:untracked_files)
    end

    def valid_selection?(data, repo_path)
      return false unless data.is_a?(Hash)
      return false unless data['repo'] == repo_path
      return false unless data['selected'].is_a?(Array)
      
      # Check if the selection is recent (less than TTL seconds old)
      timestamp = data['timestamp'].to_i
      Time.now.to_i - timestamp < SELECTION_TTL
    end

    def validate_git_repo
      unless self.class.in_repo?
        raise GitError, "Not in a Git repository"
      end
    end

    def run_command(command)
      # Use the command pool for better performance
      CommandPool.instance.execute(command)
    rescue => e
      raise GitError, "Failed to run Git command: #{e.message}"
    end

    def with_temp_file(content)
      # Create temporary file for commit message to avoid shell escaping issues
      message_file = File.join(@path, '.git', 'COMMIT_EDITMSG')
      File.write(message_file, content)
      
      yield(message_file)
    ensure
      # Clean up temp file
      File.unlink(message_file) if File.exist?(message_file)
    end

    def shell_escape(str)
      # Simple shell escaping for file paths
      str.to_s.gsub(/([^A-Za-z0-9_\-\.\/])/, '\\\\\\1')
    end
  end
end 