# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Snakommit
  # Handles configuration for snakommit
  class Config
    class ConfigError < StandardError; end
    
    CONFIG_FILE = File.join(Snakommit.config_dir, 'config.yml')
    
    # Default configuration settings
    DEFAULT_CONFIG = {
      'types' => [
        { 'name' => 'feat', 'description' => 'A new feature' },
        { 'name' => 'fix', 'description' => 'A bug fix' },
        { 'name' => 'docs', 'description' => 'Documentation changes' },
        { 'name' => 'style', 'description' => 'Changes that do not affect the meaning of the code' },
        { 'name' => 'refactor', 'description' => 'A code change that neither fixes a bug nor adds a feature' },
        { 'name' => 'perf', 'description' => 'A code change that improves performance' },
        { 'name' => 'test', 'description' => 'Adding missing tests or correcting existing tests' },
        { 'name' => 'build', 'description' => 'Changes that affect the build system or external dependencies' },
        { 'name' => 'ci/cd', 'description' => 'Changes to our CI/CD configuration files and scripts' },
        { 'name' => 'chore', 'description' => 'Other changes that don\'t modify src or test files' }
      ],
      'scopes' => [],
      'max_subject_length' => 100,
      'max_body_line_length' => 72
    }.freeze

    # Class variables for caching
    @config_cache = {}
    @config_last_modified = nil

    def self.load
      create_default_config unless File.exist?(CONFIG_FILE)
      
      # Use cached config if file hasn't been modified
      current_mtime = File.mtime(CONFIG_FILE) rescue nil
      return @config_cache.dup if @config_cache && @config_last_modified == current_mtime
      
      # Load and cache the configuration
      @config_cache = YAML.load_file(CONFIG_FILE) || {}
      @config_last_modified = current_mtime
      
      @config_cache.dup
    rescue Errno::EACCES, Errno::ENOENT => e
      raise ConfigError, "Could not load configuration: #{e.message}"
    rescue => e
      raise ConfigError, "Unexpected error loading configuration: #{e.message}"
    end

    def self.create_default_config
      # Ensure config directory exists
      config_dir = File.dirname(CONFIG_FILE)
      FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
      
      # Write default config if file doesn't exist
      unless File.exist?(CONFIG_FILE)
        File.write(CONFIG_FILE, DEFAULT_CONFIG.to_yaml)
        
        # Update cache
        @config_cache = DEFAULT_CONFIG.dup
        @config_last_modified = File.mtime(CONFIG_FILE) rescue nil
      end
      
      true
    rescue Errno::EACCES => e
      raise ConfigError, "Permission denied: #{e.message}"
    rescue => e
      raise ConfigError, "Failed to create config file: #{e.message}"
    end
    
    def self.update(updates)
      config = load.merge(updates)
      
      # Backup and write updated config
      backup_config if File.exist?(CONFIG_FILE)
      File.write(CONFIG_FILE, config.to_yaml)
      
      # Update cache
      @config_cache = config.dup
      @config_last_modified = File.mtime(CONFIG_FILE) rescue nil
      
      config
    rescue => e
      raise ConfigError, "Failed to update configuration: #{e.message}"
    end
    
    def self.get(key, default = nil)
      load.fetch(key, default)
    end
    
    def self.reset
      backup_config if File.exist?(CONFIG_FILE)
      File.write(CONFIG_FILE, DEFAULT_CONFIG.to_yaml)
      
      # Update cache
      @config_cache = DEFAULT_CONFIG.dup
      @config_last_modified = File.mtime(CONFIG_FILE) rescue nil
      
      DEFAULT_CONFIG.dup
    rescue => e
      raise ConfigError, "Failed to reset configuration: #{e.message}"
    end
    
    private
    
    def self.backup_config
      backup_file = "#{CONFIG_FILE}.bak"
      FileUtils.cp(CONFIG_FILE, backup_file)
      backup_file
    rescue => e
      warn "Warning: Failed to backup configuration: #{e.message}"
      nil
    end
  end
end 