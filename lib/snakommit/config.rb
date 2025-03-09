# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Snakommit
  # Handles configuration for snakommit
  class Config
    class ConfigError < StandardError; end
    
    CONFIG_FILE = File.join(Dir.home, '.snakommit.yml')
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

    def self.load
      create_default_config unless File.exist?(CONFIG_FILE)
      YAML.load_file(CONFIG_FILE)
    rescue Errno::EACCES, Errno::ENOENT => e
      raise ConfigError, "Could not load configuration: #{e.message}"
    rescue => e
      raise ConfigError, "Unexpected error loading configuration: #{e.message}"
    end

    def self.create_default_config
      FileUtils.mkdir_p(File.dirname(CONFIG_FILE))
      File.write(CONFIG_FILE, DEFAULT_CONFIG.to_yaml)
    rescue Errno::EACCES => e
      raise ConfigError, "Permission denied creating config file: #{e.message}"
    rescue => e
      raise ConfigError, "Unexpected error creating config file: #{e.message}"
    end
  end
end 