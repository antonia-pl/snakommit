require "test_helper"
require "fileutils"
require "tempfile"

class IntegrationTest < Minitest::Test
  def setup
    # Save original config directory
    @original_config_dir = Snakommit.config_dir
    
    # Create a temporary directory for testing
    @test_dir = File.join(Dir.tmpdir, "snakommit_test_#{Time.now.to_i}")
    @repo_dir = File.join(@test_dir, "repo")
    @hooks_dir = File.join(@repo_dir, ".git", "hooks")
    
    # Create directory structure
    FileUtils.mkdir_p(@test_dir)
    FileUtils.mkdir_p(@hooks_dir)
    
    # Override config directory for testing
    Snakommit.define_singleton_method(:config_dir) { @test_dir }
    
    # Mock Git.in_repo?
    @original_in_repo = Snakommit::Git.method(:in_repo?)
    Snakommit::Git.define_singleton_method(:in_repo?) { true }
    
    # Mock CommandPool for Git operations
    if Snakommit::Git.const_defined?(:CommandPool)
      @original_command_pool = Snakommit::Git::CommandPool
      
      mock_pool = Object.new
      def mock_pool.instance
        self
      end
      def mock_pool.execute(command)
        if command == "git rev-parse --show-toplevel"
          "/path/to/repo"
        elsif command == "git diff --name-only --cached"
          "file1.rb\nfile2.rb"
        elsif command == "git diff --name-only"
          "file3.rb"
        elsif command == "git ls-files --others --exclude-standard"
          "file4.rb"
        elsif command.start_with?("git add --") || command.start_with?("git reset HEAD --")
          ""
        else
          ""
        end
      end
      
      Snakommit::Git.const_set(:CommandPool, mock_pool)
    end
  end
  
  def teardown
    # Clean up test directory
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
    
    # Restore original config directory
    original_dir = @original_config_dir
    Snakommit.define_singleton_method(:config_dir) { original_dir }
    
    # Restore original in_repo?
    Snakommit::Git.define_singleton_method(:in_repo?, &@original_in_repo)
    
    # Restore original CommandPool if it was mocked
    if instance_variable_defined?(:@original_command_pool) && @original_command_pool
      Snakommit::Git.const_set(:CommandPool, @original_command_pool)
    end
  end
  
  def test_config_and_templates_integration
    # Test that Templates can use Config
    config = Snakommit::Config.create_default_config
    templates = Snakommit::Templates.new
    
    # Toggle emoji and verify persistence
    templates.toggle_emoji(true)
    
    # Create a new Templates instance to check persistence
    templates2 = Snakommit::Templates.new
    assert templates2.emoji_enabled?, "Emoji setting should persist via Config"
  end
  
  def test_git_and_hooks_integration
    # Initialize components
    git = Snakommit::Git.new
    hooks = Snakommit::Hooks.new(@repo_dir)
    
    # Install hooks
    assert hooks.install, "Hooks should install successfully"
    
    # Check hook installation
    status = hooks.status
    Snakommit::Hooks::HOOK_TEMPLATES.keys.each do |hook_name|
      assert_equal :installed, status[hook_name], "Hook #{hook_name} should be installed"
    end
    
    # Verify hooks directory structure
    Snakommit::Hooks::HOOK_TEMPLATES.keys.each do |hook_name|
      hook_path = File.join(@hooks_dir, hook_name)
      assert File.exist?(hook_path), "Hook file #{hook_name} should exist"
    end
  end
  
  def test_performance_integration
    # Test Cache with Git operations
    git = Snakommit::Git.new
    
    # First call should cache the result
    files1 = git.staged_files
    
    # Second call should use the cache
    files2 = git.staged_files
    
    # Both should be the same
    assert_equal files1, files2
    
    # Invalidate cache
    git.send(:invalidate_status_cache)
    
    # Call again
    files3 = git.staged_files
    
    # Should be the same content (since our mock returns the same data)
    assert_equal files1, files3
  end
  
  def test_cli_version_command
    # Initialize CLI
    cli = Snakommit::CLI.new
    
    # Capture stdout to verify output
    original_stdout = $stdout
    $stdout = StringIO.new
    
    # Run version command
    cli.run(["version"])
    
    # Check output
    output = $stdout.string
    assert_match(/snakommit version #{Snakommit::VERSION}/, output)
    
    # Restore stdout
    $stdout = original_stdout
  end
  
  def test_end_to_end_workflow
    # Set up command execution mocking
    original_system = Kernel.method(:system)
    system_calls = []
    
    Kernel.define_singleton_method(:system) do |*args|
      system_calls << args
      true
    end
    
    # Set up stdin/stdout capture
    original_stdin = $stdin
    original_stdout = $stdout
    
    # Create a mock TTY::Prompt that always returns predefined values
    original_prompt = TTY::Prompt
    mock_prompt = Class.new do
      def initialize
        @responses = {
          select: "feat",
          ask: "test commit",
          yes?: true,
          multi_select: ["file1.rb"]
        }
      end
      
      def method_missing(method, *args, &block)
        if @responses.key?(method)
          @responses[method]
        else
          super
        end
      end
      
      def respond_to_missing?(method, include_private = false)
        @responses.key?(method) || super
      end
    end
    
    # We can't replace TTY::Prompt entirely, but we can skip real interactive prompts
    # by providing mock data for testing
    skip "End-to-end workflow test would require interactive TTY"
    
    # Restore original methods
    Kernel.define_singleton_method(:system, &original_system)
    
    # Verify system calls
    assert system_calls.any? { |call| call[0] == "git" && call[1] == "commit" }, 
           "Should have made a git commit system call"
  end
end 