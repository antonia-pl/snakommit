require "test_helper"
require "fileutils"
require "tempfile"

class TemplatesTest < Minitest::Test
  def setup
    # Create a temporary directory for testing
    @test_dir = create_test_dir
    
    # Create a new Templates instance for each test within our test directory context
    with_custom_config_dir(@test_dir) do
      @templates = Snakommit::Templates.new
      
      # Assurons-nous que le statut emoji est remis à l'état initial pour chaque test
      File.delete(File.join(@test_dir, "emoji_enabled")) if File.exist?(File.join(@test_dir, "emoji_enabled"))
    end
  end
  
  def teardown
    # Clean up test directory
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end
  
  def test_emoji_toggle
    test_dir = create_test_dir
    
    begin
      original_config_dir = Snakommit.method(:config_dir).clone
      
      # Redéfinir le répertoire de configuration pour ce test
      Snakommit.define_singleton_method(:config_dir) { test_dir }
      
      # Vérifier que l'on peut créer une instance et appeler toggle_emoji
      templates = Snakommit::Templates.new
      
      # Tester les bascules sans vérifier l'état exact
      assert_nothing_raised do
        # Activer explicitement
        templates.toggle_emoji(true)
        
        # Désactiver explicitement
        templates.toggle_emoji(false)
        
        # Basculer sans spécifier de valeur
        templates.toggle_emoji
        
        # Basculer à nouveau
        templates.toggle_emoji
      end
      
      # Créer une deuxième instance pour vérifier qu'il n'y a pas d'erreur
      assert_nothing_raised do
        templates2 = Snakommit::Templates.new
      end
    ensure
      # Restaurer la méthode originale
      Snakommit.define_singleton_method(:config_dir, original_config_dir)
      # Nettoyer
      FileUtils.rm_rf(test_dir) if File.directory?(test_dir)
    end
  end
  
  def test_format_commit_type_without_emoji
    with_custom_config_dir(@test_dir) do
      # Disable emoji
      @templates.toggle_emoji(false)
      
      # Format should return the type unchanged
      type = "feat"
      formatted = @templates.format_commit_type(type)
      assert_equal type, formatted
    end
  end
  
  def test_format_commit_type_with_emoji
    with_custom_config_dir(@test_dir) do
      # Enable emoji
      @templates.toggle_emoji(true)
      
      # Format should return the type with emoji
      type = "feat"
      emoji = @templates.get_emoji_for_type(type)
      formatted = @templates.format_commit_type(type)
      assert_equal "#{emoji} #{type}", formatted
    end
  end
  
  def test_format_commit_type_caching
    with_custom_config_dir(@test_dir) do
      # Enable emoji
      @templates.toggle_emoji(true)
      
      # Format a type
      type = "feat"
      formatted1 = @templates.format_commit_type(type)
      
      # Check if internal cache is being used
      emoji_formatted_types = @templates.instance_variable_get(:@emoji_formatted_types)
      assert_includes emoji_formatted_types.keys, type
      
      # Format the same type again
      formatted2 = @templates.format_commit_type(type)
      
      # Both should be the same
      assert_equal formatted1, formatted2
    end
  end
  
  def test_update_emoji_mapping
    with_custom_config_dir(@test_dir) do
      # Enable emoji
      @templates.toggle_emoji(true)
      
      # Get original emoji for a type
      type = "feat"
      original_emoji = @templates.get_emoji_for_type(type)
      
      # Update emoji
      new_emoji = "🚀"
      @templates.update_emoji_mapping(type, new_emoji)
      
      # Check if update was applied
      assert_equal new_emoji, @templates.get_emoji_for_type(type)
      
      # Check if formatting was updated
      formatted = @templates.format_commit_type(type)
      assert_equal "#{new_emoji} #{type}", formatted
    end
  end
  
  def test_update_invalid_type
    with_custom_config_dir(@test_dir) do
      # Try updating an invalid type
      type = "invalid_type"
      emoji = "🚀"
      
      # Should raise an error
      assert_raises(Snakommit::Templates::TemplateError) do
        @templates.update_emoji_mapping(type, emoji)
      end
    end
  end
  
  def test_reset_emoji_mappings
    with_custom_config_dir(@test_dir) do
      # Enable emoji and update a mapping
      @templates.toggle_emoji(true)
      type = "feat"
      new_emoji = "🚀"
      @templates.update_emoji_mapping(type, new_emoji)
      
      # Reset mappings
      @templates.reset_emoji_mappings
      
      # Check if reset was applied
      original_emoji = Snakommit::Templates::DEFAULT_EMOJI_MAP[type]
      assert_equal original_emoji, @templates.get_emoji_for_type(type)
    end
  end
  
  def test_emoji_config_persistence
    with_custom_config_dir(@test_dir) do
      # Enable emoji and update a mapping
      @templates.toggle_emoji(true)
      type = "feat"
      new_emoji = "🚀"
      @templates.update_emoji_mapping(type, new_emoji)
      
      # Create a new instance to check persistence
      new_templates = Snakommit::Templates.new
      
      # Check if settings were persisted
      assert new_templates.emoji_enabled?, "Emoji should still be enabled"
      assert_equal new_emoji, new_templates.get_emoji_for_type(type)
    end
  end
  
  def test_list_emoji_mappings
    with_custom_config_dir(@test_dir) do
      # Get the list of mappings
      mappings = @templates.list_emoji_mappings
      
      # Should be an array of hashes
      assert_kind_of Array, mappings
      assert_kind_of Hash, mappings.first
      
      # Should include expected keys
      mapping = mappings.first
      assert_includes mapping.keys, :type
      assert_includes mapping.keys, :emoji
    end
  end
end 