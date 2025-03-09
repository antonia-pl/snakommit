# frozen_string_literal: true

module Snakommit
  # Command-line interface
  class CLI
    def initialize
      @prompt = Prompt.new
    rescue => e
      handle_initialization_error(e)
    end

    def run(args)
      command = args.shift || 'commit'

      case command
      when 'commit'
        handle_commit
      when 'version', '-v', '--version'
        puts "snakommit version #{Snakommit::VERSION}"
      when 'help', '-h', '--help'
        show_help
      else
        puts "Unknown command: #{command}"
        show_help
        exit 1
      end
    rescue => e
      handle_runtime_error(e)
    end

    private

    def handle_commit
      result = @prompt.commit_flow

      if result[:error]
        puts "Error: #{result[:error]}"
        exit 1
      elsif result[:success]
        puts "Successfully committed: #{result[:message].split("\n").first}"
      end
    end

    def show_help
      puts <<~HELP
        snakommit - Interactive conventional commit CLI

        Usage:
          snakommit [command]

        Commands:
          commit                    Create a commit using the interactive prompt (default)
          help, -h, --help          Show this help message
          version, -v, --version    Show version information

        Examples:
          snakommit                 Run the interactive commit workflow
          snakommit help            Show this help message
      HELP
    end

    def handle_initialization_error(error)
      case error
      when Config::ConfigError
        puts "Configuration error: #{error.message}"
        puts "You may need to check permissions for ~/.snakommit.yml or create it manually."
      when Git::GitError
        puts "Git error: #{error.message}"
        puts "Make sure you're in a Git repository and have Git installed."
      when Prompt::PromptError
        puts "Prompt error: #{error.message}"
        puts "Make sure your terminal supports interactive prompts."
      else
        puts "Error initializing snakommit: #{error.message}"
        puts error.backtrace.join("\n") if ENV['SNAKOMMIT_DEBUG']
      end
      exit 1
    end

    def handle_runtime_error(error)
      case error
      when Git::GitError
        puts "Git error: #{error.message}"
        puts "Make sure you have the necessary Git permissions."
      when Prompt::PromptError
        puts "Prompt error: #{error.message}"
        puts "There was an issue with the interactive prompts."
      else
        puts "Error running snakommit: #{error.message}"
        puts error.backtrace.join("\n") if ENV['SNAKOMMIT_DEBUG']
      end
      exit 1
    end
  end
end 