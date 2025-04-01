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
        { 'name' => 'ci', 'description' => 'Changes to our CI configuration files and scripts' },
        { 'name' => 'chore', 'description' => 'Other changes that don\'t modify src or test files' }
      ],
      'scopes' => [],
      'max_subject_length' => 100,
      'max_body_line_length' => 72
    }.freeze

    # Initialiser les variables de classe
    @config_cache = {}
    @config_last_modified = nil

    # Load configuration from file, creating default if needed
    # @return [Hash] The configuration hash
    # @raise [ConfigError] If configuration can't be loaded
    def self.load
      create_default_config unless File.exist?(CONFIG_FILE)
      
      # Check if config file has been modified since last load
      current_mtime = File.mtime(CONFIG_FILE) rescue nil
      
      # Return cached config if it exists and file hasn't been modified
      if @config_cache && @config_last_modified == current_mtime
        return @config_cache.dup
      end
      
      # Load and cache the configuration
      @config_cache = YAML.load_file(CONFIG_FILE) || {}
      @config_last_modified = current_mtime
      
      # Return a copy to prevent unintentional modifications
      @config_cache.dup
    rescue Errno::EACCES, Errno::ENOENT => e
      raise ConfigError, "Could not load configuration: #{e.message}"
    rescue => e
      raise ConfigError, "Unexpected error loading configuration: #{e.message}"
    end

    # Create the default configuration file
    # @return [Boolean] True if successful
    # @raise [ConfigError] If default config can't be created
    def self.create_default_config
      # Check if directory exists
      config_dir = File.dirname(CONFIG_FILE)
      unless Dir.exist?(config_dir)
        begin
          FileUtils.mkdir_p(config_dir)
        rescue Errno::EACCES => e
          raise ConfigError, "Permission denied creating config directory: #{e.message}"
        end
      end
      
      # Write config file if it doesn't exist
      unless File.exist?(CONFIG_FILE)
        begin
          File.write(CONFIG_FILE, DEFAULT_CONFIG.to_yaml)
          
          # Update cache
          @config_cache = DEFAULT_CONFIG.dup
          @config_last_modified = File.mtime(CONFIG_FILE) rescue nil
        rescue Errno::EACCES => e
          raise ConfigError, "Permission denied creating config file: #{e.message}"
        rescue => e
          raise ConfigError, "Unexpected error creating config file: #{e.message}"
        end
      end
      
      true
    end
    
    # Update configuration values
    # @param updates [Hash] Configuration values to update
    # @return [Hash] The updated configuration
    # @raise [ConfigError] If configuration can't be updated
    def self.update(updates)
      config = load
      config.merge!(updates)
      
      # Create a backup of the current configuration
      backup_config if File.exist?(CONFIG_FILE)
      
      # Write the updated configuration
      File.write(CONFIG_FILE, config.to_yaml)
      
      # Update cache
      @config_cache = config.dup
      @config_last_modified = File.mtime(CONFIG_FILE) rescue nil
      
      config
    rescue => e
      raise ConfigError, "Failed to update configuration: #{e.message}"
    end
    
    # Get a specific configuration value
    # @param key [String] Configuration key
    # @param default [Object] Default value if key not found
    # @return [Object] Configuration value or default
    def self.get(key, default = nil)
      config = load
      config.fetch(key, default)
    end
    
    # Reset configuration to defaults
    # @return [Hash] The default configuration
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
    
    # Backup the current configuration
    # @return [String] Path to backup file
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