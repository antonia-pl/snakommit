$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "snakommit"
require "minitest/autorun"
require "minitest/pride" # For colorful output
require "fileutils"
require "tempfile"

module TestHelpers
  # Utility method to create a temporary test directory
  def create_test_dir
    test_dir = File.join(Dir.tmpdir, "snakommit_test_#{Time.now.to_i}_#{rand(1000)}")
    FileUtils.mkdir_p(test_dir)
    test_dir
  end
  
  # Utility method to create a mock git repository structure
  def create_mock_repo
    repo_dir = create_test_dir
    git_dir = File.join(repo_dir, ".git")
    hooks_dir = File.join(git_dir, "hooks")
    FileUtils.mkdir_p(hooks_dir)
    [repo_dir, git_dir, hooks_dir]
  end
  
  # Safely override Snakommit.config_dir
  def with_custom_config_dir(dir)
    original_method = Snakommit.method(:config_dir) rescue nil
    Snakommit.define_singleton_method(:config_dir) { dir }
    yield
  ensure
    if original_method
      Snakommit.define_singleton_method(:config_dir, original_method)
    else
      Snakommit.singleton_class.send(:remove_method, :config_dir)
    end
  end
  
  # Safely override a constant
  def with_replaced_constant(namespace, constant_name, new_value)
    original_value = namespace.const_get(constant_name)
    namespace.send(:remove_const, constant_name)
    namespace.const_set(constant_name, new_value)
    yield
  ensure
    namespace.send(:remove_const, constant_name)
    namespace.const_set(constant_name, original_value)
  end
  
  # Safely override a method
  def with_replaced_method(target, method_name, new_method)
    if target.respond_to?(method_name)
      original_method = target.method(method_name)
      target.define_singleton_method(method_name, new_method)
      yield
      target.define_singleton_method(method_name, original_method)
    else
      target.define_singleton_method(method_name, new_method)
      yield
      target.singleton_class.send(:remove_method, method_name)
    end
  end
end

# Include helpers in Minitest
class Minitest::Test
  include TestHelpers
  
  # Affirme qu'aucune exception n'est levée pendant l'exécution du bloc
  def assert_nothing_raised(msg = nil)
    begin
      yield
      assert true # Réussi si aucune exception n'est levée
    rescue => e
      flunk(msg || "Exception levée: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
    end
  end
end 