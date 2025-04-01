# frozen_string_literal: true

module Snakommit
  # Command-line interface
  class CLI
    class CLIError < StandardError; end
    
    COMMANDS = {
      'commit' => 'Create a commit using the interactive prompt',
      'emoji' => 'Toggle emoji display in commit messages',
      'templates' => 'Manage emoji for commit types',
      'hooks' => 'Manage Git hooks integration',
      'update' => 'Check for and install the latest version',
      'version' => 'Show version information',
      'help' => 'Show help information'
    }.freeze

    def initialize
      @monitor = Performance::Monitor.new
      @prompt = @monitor.measure(:init_prompt) { Prompt.new }
      @templates = @monitor.measure(:init_templates) { Templates.new }
      @hooks = @monitor.measure(:init_hooks) { Hooks.new }
    rescue => e
      handle_initialization_error(e)
    end

    def run(args)
      command = args.shift || 'commit'
      
      # Start monitoring execution time
      trace_start = Time.now
      
      # Execute the command with performance monitoring
      result = @monitor.measure(:command_execution) do
        execute_command(command, args)
      end
      
      # Record command execution metrics if in debug mode
      if ENV['SNAKOMMIT_DEBUG']
        trace_end = Time.now
        puts "\nCommand execution completed in #{(trace_end - trace_start).round(3)}s"
        puts "Performance breakdown:"
        @monitor.report.each { |line| puts "  #{line}" }
      end
      
      result
    rescue => e
      handle_runtime_error(e)
    end
    
    private
    
    def execute_command(command, args)
      case command
      when 'commit'
        handle_commit
      when 'version', '-v', '--version'
        show_version
      when 'help', '-h', '--help'
        show_help
      when 'hooks'
        handle_hooks(args)
      when 'templates'
        handle_templates(args)
      when 'emoji'
        handle_emoji_toggle(args)
      when 'update'
        check_for_updates(args.include?('--force'))
      when 'validate-message'
        validate_commit_message(args.first)
      when 'prepare-message'
        prepare_commit_message
      when 'log-commit'
        log_commit(args.first)
      else
        unknown_command(command)
      end
    end

    def handle_commit
      result = @prompt.commit_flow

      if result[:error]
        puts "Error: #{result[:error]}"
        exit 1
      elsif result[:success]
        puts "Successfully committed: #{result[:message].split("\n").first}"
      end
    end

    def show_version
      puts "snakommit version #{Snakommit::VERSION}"
    end

    def unknown_command(command)
      puts "Unknown command: #{command}"
      show_help
      exit 1
    end

    def handle_emoji_toggle(args)
      state = args.shift
      if state && ['on', 'off'].include?(state.downcase)
        enable = state.downcase == 'on'
        @templates.toggle_emoji(enable)
        emoji_status = @templates.emoji_enabled? ? 'enabled' : 'disabled'
        puts "Emojis are now #{emoji_status} for commit types"
      else
        puts "Usage: snakommit emoji [on|off]"
        exit 1
      end
    end

    def show_help
      usage_text = <<~HELP
        snakommit - Interactive conventional commit CLI

        Usage:
          snakommit [command]

        Commands:
          commit                    Create a commit using the interactive prompt (default)
          emoji [on|off]            Quick toggle for emoji display in commit messages
          hooks [install|uninstall|status] [hook]  Manage Git hooks integration
          templates [command]       Manage emoji for commit types
            list                    List available emoji mappings for commit types
            update <type> <emoji>   Update emoji for a specific commit type
            reset                   Reset all emoji mappings to defaults
          update [--force]          Check for and install the latest version
          validate-message <file>   Validate a commit message file (used by Git hooks)
          prepare-message           Prepare a commit message (used by Git hooks)
          help, -h, --help          Show this help message
          version, -v, --version    Show version information

        Examples:
          snakommit                 Run the interactive commit workflow
          sk emoji on               Enable emojis in commit messages
          sk emoji off              Disable emojis in commit messages
          sk update                 Update to the latest version
          snakommit hooks install   Install all Git hooks
          snakommit help            Show this help message
      HELP

      puts usage_text
    end

    def handle_hooks(args)
      subcommand = args.shift || 'status'
      hook_name = args.shift # Optional specific hook name

      case subcommand
      when 'install'
        if @hooks.install(hook_name)
          puts "Git #{hook_name || 'hooks'} installed successfully"
        else
          puts "Failed to install Git #{hook_name || 'hooks'}"
          exit 1
        end
      when 'uninstall'
        if @hooks.uninstall(hook_name)
          puts "Git #{hook_name || 'hooks'} uninstalled successfully"
        else
          puts "Git #{hook_name || 'hooks'} not found or not installed by snakommit"
        end
      when 'status'
        show_hooks_status(hook_name)
      else
        puts "Unknown hooks subcommand: #{subcommand}"
        show_help
        exit 1
      end
    end

    def show_hooks_status(hook_name)
      status = @hooks.status
      if hook_name
        puts "#{hook_name}: #{status[hook_name] || 'unknown'}"
      else
        puts "Git hooks status:"
        status.each do |hook, state|
          puts "  #{hook}: #{state}"
        end
      end
    end

    def handle_templates(args)
      subcommand = args.shift || 'list'
      
      case subcommand
      when 'list'
        list_emoji_mappings
      when 'update'
        update_emoji_mapping(args)
      when 'reset'
        reset_emoji_mappings
      else
        puts "Unknown templates subcommand: #{subcommand}"
        show_help
        exit 1
      end
    end

    def list_emoji_mappings
      mappings = @templates.list_emoji_mappings
      puts "Emoji mappings for commit types:"
      mappings.each do |mapping|
        puts "  #{mapping[:type]}: #{mapping[:emoji]}"
      end
    end

    def update_emoji_mapping(args)
      type = args.shift
      emoji = args.shift
      
      if type && emoji
        begin
          @templates.update_emoji_mapping(type, emoji)
          puts "Updated emoji for #{type} to #{emoji}"
        rescue Templates::TemplateError => e
          puts "Error: #{e.message}"
          exit 1
        end
      else
        puts "Error: Missing arguments. Usage: snakommit templates update <type> <emoji>"
        exit 1
      end
    end

    def reset_emoji_mappings
      @templates.reset_emoji_mappings
      puts "Reset all emoji mappings to defaults"
    end

    def validate_commit_message(file_path)
      unless file_path && File.exist?(file_path)
        puts "Error: Commit message file not specified or not found"
        exit 1
      end

      message = File.read(file_path)
      # Simple validation - use active template's validation later
      if message.strip.empty? || message.lines.first.to_s.strip.empty?
        puts "Error: Empty commit message"
        exit 1
      end

      exit 0
    end

    def prepare_commit_message
      # This would normally invoke the interactive prompt
      # For now, just return a simple message for testing
      puts "chore: automated commit message from snakommit"
      exit 0
    end

    def log_commit(commit_hash)
      # In the future, this will store commit stats
      exit 0 if commit_hash
      exit 1
    end

    def check_for_updates(force = false)
      require 'open-uri'
      require 'json'
      
      puts "Checking for updates..."
      
      begin
        # Get the latest version from RubyGems
        response = nil
        @monitor.measure(:fetch_rubygems) do
          response = URI.open("https://rubygems.org/api/v1/gems/snakommit.json").read
        end
        
        data = JSON.parse(response)
        latest_version = data["version"]
        current_version = Snakommit::VERSION
        
        # Compare versions
        if force || latest_version > current_version
          update_gem(latest_version, current_version)
        else
          puts "You are already using the latest version (#{current_version})"
        end
      rescue => e
        puts "Failed to check for updates: #{e.message}"
        exit 1
      end
    end
    
    # Update to the latest gem version
    def update_gem(latest_version, current_version)
      puts "New version available: #{latest_version} (current: #{current_version})"
      
      # Confirm update
      puts "Do you want to update? (Y/n)"
      response = STDIN.gets.strip.downcase
      return if response == 'n'
      
      # Run the gem update command with a spinner
      require 'tty-spinner'
      spinner = TTY::Spinner.new("[:spinner] Updating to v#{latest_version}... ", format: :dots)
      spinner.auto_spin
      
      begin
        result = @monitor.measure(:gem_update) do
          system("gem install snakommit -v #{latest_version}")
        end
        
        if result
          spinner.success("Update successful! Restart to use the new version.")
        else
          spinner.error("Update failed with status code: #{$?.exitstatus}")
          puts "Try running manually: gem install snakommit -v #{latest_version}"
          exit 1
        end
      rescue => e
        spinner.error("Update failed: #{e.message}")
        exit 1
      end
    end

    # Handle initialization errors in a user-friendly way
    def handle_initialization_error(error)
      case error
      when Prompt::PromptError
        puts "Error initializing prompt: #{error.message}"
      when Templates::TemplateError
        puts "Error initializing templates: #{error.message}"
      when Hooks::HookError
        puts "Error initializing hooks: #{error.message}"
      when Config::ConfigError
        puts "Error loading configuration: #{error.message}"
      when Git::GitError
        puts "Git error: #{error.message}"
      else
        puts "Initialization error: #{error.message}"
        puts "Backtrace:\n  #{error.backtrace.join("\n  ")}" if ENV['SNAKOMMIT_DEBUG']
      end
      
      puts "\nTrying to run snakommit in a non-Git repository? Make sure you're in a valid Git repository."
      puts "For more information, run 'snakommit help'"
      exit 1
    end

    # Handle runtime errors in a user-friendly way
    def handle_runtime_error(error)
      case error
      when Prompt::PromptError
        puts "Error during prompt: #{error.message}"
      when Templates::TemplateError
        puts "Template error: #{error.message}"
      when Hooks::HookError
        puts "Hook error: #{error.message}"
      when Config::ConfigError
        puts "Configuration error: #{error.message}"
      when Git::GitError
        puts "Git error: #{error.message}"
      when CLIError
        puts "CLI error: #{error.message}"
      else
        puts "Error: #{error.message}"
        puts "Backtrace:\n  #{error.backtrace.join("\n  ")}" if ENV['SNAKOMMIT_DEBUG']
      end
      
      puts "\nFor help, run 'snakommit help'"
      exit 1
    end
  end
end 