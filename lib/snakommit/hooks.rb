# frozen_string_literal: true

require 'fileutils'

module Snakommit
  # Manages Git hooks integration
  class Hooks
    class HookError < StandardError; end

    # Templates for various Git hooks
    HOOK_TEMPLATES = {
      'prepare-commit-msg' => <<~HOOK,
        #!/bin/sh
        # Snakommit prepare-commit-msg hook
        
        # Skip if message is already prepared (e.g., merge)
        if [ -n "$2" ]; then
          exit 0
        fi
        
        # Capture original commit message if it exists
        original_message=""
        if [ -s "$1" ]; then
          original_message=$(cat "$1")
        fi
        
        # Run snakommit and use its output as the commit message
        # If snakommit exits with non-zero, fall back to original message
        message=$(snakommit prepare-message 2>/dev/null)
        if [ $? -eq 0 ]; then
          echo "$message" > "$1"
        else
          if [ -n "$original_message" ]; then
            echo "$original_message" > "$1"
          fi
        fi
      HOOK
      
      'commit-msg' => <<~HOOK,
        #!/bin/sh
        # Snakommit commit-msg hook
        
        # Validate the commit message using snakommit
        snakommit validate-message "$1"
        if [ $? -ne 0 ]; then
          echo "ERROR: Your commit message does not conform to standard format."
          echo "Please run 'snakommit help format' for more information."
          exit 1
        fi
      HOOK
      
      'post-commit' => <<~HOOK
        #!/bin/sh
        # Snakommit post-commit hook
        
        # Log this commit in snakommit's history
        snakommit log-commit $(git log -1 --format="%H") >/dev/null 2>&1
      HOOK
    }.freeze

    # Magic signature to identify our hooks
    HOOK_SIGNATURE = '# Snakommit'.freeze

    # Initialize with a Git repository path
    # @param git_repo_path [String] Path to Git repository, defaults to current directory
    def initialize(git_repo_path = Dir.pwd)
      @git_repo_path = git_repo_path
      @hooks_dir = File.join(@git_repo_path, '.git', 'hooks')
      @hook_status_cache = {}
      ensure_hooks_directory
    end

    # Install one or all hooks
    # @param hook_name [String, nil] Specific hook to install, or nil for all hooks
    # @return [Boolean] Success status
    def install(hook_name = nil)
      # Invalidate status cache
      @hook_status_cache.clear
      
      if hook_name
        install_hook(hook_name)
      else
        # Use batch processing if available
        if defined?(Performance::BatchProcessor)
          batch_processor = Performance::BatchProcessor.new(3)
          result = true
          batch_processor.process_files(HOOK_TEMPLATES.keys) do |batch|
            batch.each do |hook|
              result = false unless install_hook(hook)
            end
          end
          result
        else
          HOOK_TEMPLATES.keys.all? { |hook| install_hook(hook) }
        end
      end
    end

    # Uninstall one or all hooks
    # @param hook_name [String, nil] Specific hook to uninstall, or nil for all hooks
    # @return [Boolean] Success status
    def uninstall(hook_name = nil)
      # Invalidate status cache
      @hook_status_cache.clear
      
      if hook_name
        uninstall_hook(hook_name)
      else
        HOOK_TEMPLATES.keys.all? { |hook| uninstall_hook(hook) }
      end
    end

    # Check the status of installed hooks
    # @return [Hash] Status of each hook (:installed, :conflict, or :not_installed)
    def status
      # Use cached status if available and not empty
      return @hook_status_cache if @hook_status_cache.any?
      
      @hook_status_cache = HOOK_TEMPLATES.keys.each_with_object({}) do |hook_name, status|
        hook_path = File.join(@hooks_dir, hook_name)
        
        if File.exist?(hook_path)
          if hook_is_snakommit?(hook_path)
            status[hook_name] = :installed
          else
            status[hook_name] = :conflict
          end
        else
          status[hook_name] = :not_installed
        end
      end
    end

    private

    # Ensure hooks directory exists
    # @raise [HookError] If hooks directory not found
    def ensure_hooks_directory
      unless Dir.exist?(@hooks_dir)
        raise HookError, "Git hooks directory not found. Are you in a Git repository?"
      end
    end

    # Install a specific hook
    # @param hook_name [String] Name of the hook to install
    # @return [Boolean] Success status
    # @raise [HookError] If hook installation fails
    def install_hook(hook_name)
      unless HOOK_TEMPLATES.key?(hook_name)
        raise HookError, "Unknown hook: #{hook_name}"
      end

      hook_path = File.join(@hooks_dir, hook_name)
      
      # Only backup if the hook exists and is not already a Snakommit hook
      if File.exist?(hook_path) && !hook_is_snakommit?(hook_path)
        backup_existing_hook(hook_path)
      end
      
      # Write the hook file in a single operation
      File.write(hook_path, HOOK_TEMPLATES[hook_name])
      FileUtils.chmod(0755, hook_path) # Make hook executable
      
      true
    rescue Errno::EACCES => e
      raise HookError, "Permission denied: #{e.message}"
    rescue => e
      raise HookError, "Failed to install hook: #{e.message}"
    end

    # Uninstall a specific hook
    # @param hook_name [String] Name of the hook to uninstall
    # @return [Boolean] Success status
    # @raise [HookError] If hook uninstallation fails
    def uninstall_hook(hook_name)
      hook_path = File.join(@hooks_dir, hook_name)
      
      # Only remove if it's our hook
      if hook_is_snakommit?(hook_path)
        # Try to restore backup first, delete if no backup
        restore_backup_hook(hook_path) || File.delete(hook_path)
        true
      else
        false
      end
    rescue Errno::EACCES => e
      raise HookError, "Permission denied: #{e.message}"
    rescue => e
      raise HookError, "Failed to uninstall hook: #{e.message}"
    end

    # Check if a hook file is a Snakommit hook
    # @param hook_path [String] Path to the hook file
    # @return [Boolean] True if it's a Snakommit hook
    def hook_is_snakommit?(hook_path)
      return false unless File.exist?(hook_path)
      
      # Fast check - read first few lines only
      File.open(hook_path) do |file|
        10.times do  # Increase the number of lines checked
          line = file.gets
          return true if line && line.include?(HOOK_SIGNATURE)
          break if line.nil?
        end
      end
      
      false
    rescue => e
      # If we can't read the file, it's not our hook
      false
    end

    # Backup an existing hook file
    # @param hook_path [String] Path to the hook file
    # @return [String, nil] Path to the backup file or nil if no backup created
    def backup_existing_hook(hook_path)
      # Don't overwrite existing backup
      backup_path = "#{hook_path}.backup"
      if File.exist?(backup_path)
        backup_path = "#{hook_path}.backup.#{Time.now.to_i}"
      end
      
      # Create the backup
      FileUtils.cp(hook_path, backup_path)
      backup_path
    rescue => e
      # Log but continue if backup fails
      warn "Warning: Failed to backup hook at #{hook_path}: #{e.message}" if ENV['SNAKOMMIT_DEBUG']
      nil
    end

    # Restore a backed-up hook file
    # @param hook_path [String] Path to the original hook file
    # @return [Boolean] True if backup was restored, false otherwise
    def restore_backup_hook(hook_path)
      backup_path = "#{hook_path}.backup"
      
      # Check for timestamped backups if standard one doesn't exist
      unless File.exist?(backup_path)
        backup_glob = "#{hook_path}.backup.*"
        backups = Dir.glob(backup_glob).sort_by { |f| File.mtime(f) }
        backup_path = backups.last unless backups.empty?
      end
      
      # Restore the backup if it exists
      if File.exist?(backup_path)
        FileUtils.mv(backup_path, hook_path)
        true
      else
        false
      end
    rescue => e
      # Log but continue if restore fails
      warn "Warning: Failed to restore hook backup at #{backup_path}: #{e.message}" if ENV['SNAKOMMIT_DEBUG']
      false
    end
  end
end 