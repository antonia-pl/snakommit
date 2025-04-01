require "test_helper"
require "fileutils"
require "tempfile"

class HooksTest < Minitest::Test
  def setup
    # Create a temporary directory structure simulating a Git repo
    @repo_dir, @git_dir, @hooks_dir = create_mock_repo
    
    # Initialize Hooks with the test repo
    @hooks = Snakommit::Hooks.new(@repo_dir)
  end
  
  def teardown
    # Clean up test directory
    FileUtils.rm_rf(@repo_dir) if @repo_dir && Dir.exist?(@repo_dir)
  end
  
  def test_ensure_hooks_directory
    # Should not raise error since we created the hooks directory
    assert_silent { @hooks.send(:ensure_hooks_directory) }
    
    # Remove hooks directory
    FileUtils.rm_rf(@hooks_dir)
    
    # Should raise error now
    assert_raises(Snakommit::Hooks::HookError) do
      @hooks.send(:ensure_hooks_directory)
    end
  end
  
  def test_install_hook
    # Install a hook
    hook_name = "prepare-commit-msg"
    result = @hooks.send(:install_hook, hook_name)
    assert result, "Hook installation should succeed"
    
    # Check if hook file exists
    hook_path = File.join(@hooks_dir, hook_name)
    assert File.exist?(hook_path), "Hook file should exist"
    
    # Check if hook is executable
    assert File.executable?(hook_path), "Hook should be executable"
    
    # Check if hook content is correct
    content = File.read(hook_path)
    assert_equal Snakommit::Hooks::HOOK_TEMPLATES[hook_name], content
    
    # Try installing an invalid hook
    assert_raises(Snakommit::Hooks::HookError) do
      @hooks.send(:install_hook, "invalid-hook")
    end
  end
  
  def test_install_all_hooks
    # Install all hooks
    result = @hooks.install
    assert result, "All hooks should be installed successfully"
    
    # Check if all hook files exist
    Snakommit::Hooks::HOOK_TEMPLATES.keys.each do |hook_name|
      hook_path = File.join(@hooks_dir, hook_name)
      assert File.exist?(hook_path), "Hook file #{hook_name} should exist"
    end
  end
  
  def test_install_specific_hook
    # Install a specific hook
    hook_name = "commit-msg"
    result = @hooks.install(hook_name)
    assert result, "Hook installation should succeed"
    
    # Check if hook file exists
    hook_path = File.join(@hooks_dir, hook_name)
    assert File.exist?(hook_path), "Hook file should exist"
    
    # Check that only the specified hook was installed
    other_hooks = Snakommit::Hooks::HOOK_TEMPLATES.keys - [hook_name]
    other_hooks.each do |other_hook|
      hook_path = File.join(@hooks_dir, other_hook)
      refute File.exist?(hook_path), "Hook file #{other_hook} should not exist"
    end
  end
  
  def test_hook_is_snakommit
    # Create a Snakommit hook
    hook_name = "prepare-commit-msg"
    hook_path = File.join(@hooks_dir, hook_name)
    File.write(hook_path, Snakommit::Hooks::HOOK_TEMPLATES[hook_name])
    
    # Should be identified as a Snakommit hook
    assert @hooks.send(:hook_is_snakommit?, hook_path)
    
    # Create a non-Snakommit hook
    hook_name = "post-commit"
    hook_path = File.join(@hooks_dir, hook_name)
    File.write(hook_path, "#!/bin/sh\necho 'This is not a Snakommit hook'")
    
    # Should not be identified as a Snakommit hook
    refute @hooks.send(:hook_is_snakommit?, hook_path)
    
    # Non-existent hook
    hook_path = File.join(@hooks_dir, "non-existent")
    refute @hooks.send(:hook_is_snakommit?, hook_path)
  end
  
  def test_uninstall_hook
    # Install a hook first
    hook_name = "prepare-commit-msg"
    @hooks.install(hook_name)
    
    # Uninstall the hook
    result = @hooks.uninstall(hook_name)
    assert result, "Hook uninstallation should succeed"
    
    # Check if hook file was removed
    hook_path = File.join(@hooks_dir, hook_name)
    refute File.exist?(hook_path), "Hook file should not exist after uninstallation"
  end
  
  def test_uninstall_all_hooks
    # Install all hooks first
    @hooks.install
    
    # Uninstall all hooks
    result = @hooks.uninstall
    assert result, "All hooks should be uninstalled successfully"
    
    # Check if all hook files were removed
    Snakommit::Hooks::HOOK_TEMPLATES.keys.each do |hook_name|
      hook_path = File.join(@hooks_dir, hook_name)
      refute File.exist?(hook_path), "Hook file #{hook_name} should not exist after uninstallation"
    end
  end
  
  def test_backup_existing_hook
    # Create a non-Snakommit hook
    hook_name = "prepare-commit-msg"
    hook_path = File.join(@hooks_dir, hook_name)
    original_content = "#!/bin/sh\necho 'This is an existing hook'"
    File.write(hook_path, original_content)
    
    # Backup the hook
    backup_path = @hooks.send(:backup_existing_hook, hook_path)
    assert backup_path, "Backup should succeed and return path"
    assert File.exist?(backup_path), "Backup file should exist"
    
    # Check backup content
    backup_content = File.read(backup_path)
    assert_equal original_content, backup_content
  end
  
  def test_restore_backup_hook
    # Create a hook and back it up
    hook_name = "prepare-commit-msg"
    hook_path = File.join(@hooks_dir, hook_name)
    original_content = "#!/bin/sh\necho 'This is an existing hook'"
    File.write(hook_path, original_content)
    
    # Create backup
    backup_path = "#{hook_path}.backup"
    FileUtils.cp(hook_path, backup_path)
    
    # Overwrite original
    File.write(hook_path, "New content")
    
    # Restore backup
    result = @hooks.send(:restore_backup_hook, hook_path)
    assert result, "Restore should succeed"
    
    # Check restored content
    restored_content = File.read(hook_path)
    assert_equal original_content, restored_content
    
    # Backup file should be gone
    refute File.exist?(backup_path), "Backup file should be moved (deleted) after restore"
  end
  
  def test_status
    # Invalider le cache de statut d'abord
    @hooks.instance_variable_set(:@hook_status_cache, {})
    
    # Initialement, tous les hooks devraient être non installés
    status = @hooks.status
    Snakommit::Hooks::HOOK_TEMPLATES.keys.each do |hook_name|
      assert_equal :not_installed, status[hook_name]
    end
    
    # Installer un hook
    hook_name = "prepare-commit-msg"
    hook_path = File.join(@hooks_dir, hook_name)
    
    # Vérifier que le contenu contient la signature
    content = Snakommit::Hooks::HOOK_TEMPLATES[hook_name]
    assert content.include?(Snakommit::Hooks::HOOK_SIGNATURE), "Le template du hook doit contenir la signature"
    
    # Écrire le hook avec la signature correcte
    File.write(hook_path, content)
    File.chmod(0755, hook_path)
    
    # Invalider manuellement le cache pour les tests
    @hooks.instance_variable_set(:@hook_status_cache, {})
    
    # Vérifier si le statut est mis à jour
    status = @hooks.status
    assert_equal :installed, status[hook_name], "Le hook #{hook_name} devrait être installé"
    
    # Créer un conflit
    hook_name = "commit-msg"
    hook_path = File.join(@hooks_dir, hook_name)
    File.write(hook_path, "#!/bin/sh\necho 'This is a conflicting hook'")
    File.chmod(0755, hook_path)
    
    # Invalider manuellement le cache pour les tests
    @hooks.instance_variable_set(:@hook_status_cache, {})
    
    # Vérifier si le conflit est détecté
    status = @hooks.status
    assert_equal :conflict, status[hook_name], "Le hook #{hook_name} devrait être en conflit"
  end
  
  def test_status_caching
    # Get initial status
    status1 = @hooks.status
    
    # Install a hook but don't invalidate cache
    hook_name = "prepare-commit-msg"
    hook_path = File.join(@hooks_dir, hook_name)
    File.write(hook_path, Snakommit::Hooks::HOOK_TEMPLATES[hook_name])
    
    # Status should be unchanged due to caching
    status2 = @hooks.status
    assert_equal status1, status2
    
    # Clear cache by calling install
    @hooks.install
    
    # Status should be updated now
    status3 = @hooks.status
    refute_equal status1, status3
    assert_equal :installed, status3[hook_name]
  end
end 