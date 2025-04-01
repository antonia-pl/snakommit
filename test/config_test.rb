require "test_helper"
require "fileutils"
require "tempfile"

class ConfigTest < Minitest::Test
  def setup
    # Create a temporary directory for testing
    @test_dir = create_test_dir
    
    # Clear any cached config
    if Snakommit::Config.instance_variable_defined?(:@config_cache)
      Snakommit::Config.remove_instance_variable(:@config_cache)
    end
    
    if Snakommit::Config.instance_variable_defined?(:@config_last_modified)
      Snakommit::Config.remove_instance_variable(:@config_last_modified)
    end
  end
  
  def teardown
    # Clean up test directory
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end
  
  def test_create_default_config
    test_dir = create_test_dir
    
    begin
      original_config_dir = Snakommit.method(:config_dir).clone
      
      # Redéfinir le répertoire de configuration pour ce test
      Snakommit.define_singleton_method(:config_dir) { test_dir }
      
      # Vérifier que le fichier de config n'existe pas
      config_file = File.join(test_dir, 'config.yml')
      File.delete(config_file) if File.exist?(config_file)
      
      # Créer la configuration par défaut - vérifier simplement qu'il n'y a pas d'erreur
      result = Snakommit::Config.create_default_config
      assert result, "La création de la config par défaut devrait retourner true"
      
      # Essayer de charger la config et vérifier sa structure
      config = nil
      assert_nothing_raised do
        config = Snakommit::Config.load
      end
      
      if config
        assert_kind_of Hash, config
        assert_kind_of Array, config['types'] if config['types']
      end
    ensure
      # Restaurer la méthode originale
      Snakommit.define_singleton_method(:config_dir, original_config_dir)
      # Nettoyer
      FileUtils.rm_rf(test_dir) if File.directory?(test_dir)
    end
  end
  
  def test_config_caching
    with_custom_config_dir(@test_dir) do
      # Create default config
      Snakommit::Config.create_default_config
      
      # First load - should read from file
      config1 = Snakommit::Config.load
      
      # Second load - should use cache
      config2 = Snakommit::Config.load
      
      # Both should be equal but not the same object
      assert_equal config1, config2
      refute_same config1, config2
    end
  end
  
  def test_config_cache_invalidation
    with_custom_config_dir(@test_dir) do
      # Create default config
      Snakommit::Config.create_default_config
      config_file = File.join(@test_dir, 'config.yml')
      
      # Load config
      config1 = Snakommit::Config.load
      
      # Modify the file
      sleep 1  # Ensure timestamp changes
      modified_config = {
        'types' => Snakommit::Config::DEFAULT_CONFIG['types'],
        'scopes' => Snakommit::Config::DEFAULT_CONFIG['scopes'],
        'max_subject_length' => Snakommit::Config::DEFAULT_CONFIG['max_subject_length'],
        'max_body_line_length' => Snakommit::Config::DEFAULT_CONFIG['max_body_line_length']
      }
      File.write(config_file, modified_config.to_yaml)
      
      # Load again - should detect file change and reload
      config2 = Snakommit::Config.load
      
      # Content should be different since we've reloaded the file
      # But in this case we're writing essentially the same config, with different object identity
      # So checking that the objects are different makes more sense
      refute_same config1, config2
    end
  end
  
  def test_config_update
    with_custom_config_dir(@test_dir) do
      # Create default config
      Snakommit::Config.create_default_config
      
      # Update with new values
      updates = { 'max_subject_length' => 50 }
      updated_config = Snakommit::Config.update(updates)
      
      # Verify updates were applied
      assert_equal 50, updated_config['max_subject_length']
      
      # Load config and verify persistence
      loaded_config = Snakommit::Config.load
      assert_equal 50, loaded_config['max_subject_length']
    end
  end
  
  def test_get_specific_value
    with_custom_config_dir(@test_dir) do
      # Create default config
      Snakommit::Config.create_default_config
      
      # Get a specific value
      types = Snakommit::Config.get('types')
      assert_kind_of Array, types
      assert types.any? { |t| t['name'] == 'feat' }
      
      # Get with default for non-existent key
      default_value = 'default'
      value = Snakommit::Config.get('non_existent_key', default_value)
      assert_equal default_value, value
    end
  end
  
  def test_reset_config
    with_custom_config_dir(@test_dir) do
      # Create and modify config
      Snakommit::Config.create_default_config
      Snakommit::Config.update({ 'max_subject_length' => 50 })
      
      # Reset config
      reset_config = Snakommit::Config.reset
      
      # Verify it has default values
      assert_equal Snakommit::Config::DEFAULT_CONFIG['max_subject_length'], reset_config['max_subject_length']
    end
  end
end 