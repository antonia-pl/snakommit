# frozen_string_literal: true

module Snakommit
  # Command-line interface
  class CLI
    def initialize
      @prompt = Prompt.new
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
  end
end 