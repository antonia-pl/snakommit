# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Snakommit
  # Manages commit message formatting and emoji options
  class Templates
    class TemplateError < StandardError; end

    # Emoji mappings for commit types
    DEFAULT_EMOJI_MAP = {
      'feat' => '✨', # sparkles
      'fix' => '🐛', # bug
      'docs' => '📝', # memo
      'style' => '💄', # lipstick
      'refactor' => '♻️', # recycle
      'perf' => '⚡️', # zap
      'test' => '✅', # check mark
      'build' => '🔧', # wrench
      'ci/cd' => '👷', # construction worker
      'chore' => '🔨', # hammer
      'revert' => '⏪️', # rewind
    }.freeze

    # Configuration file path
    CONFIG_FILE = File.join(Snakommit.config_dir, 'emoji_config.yml')

    def initialize
      ensure_config_directory
      @emoji_formatted_types = {} # Cache for formatted commit types
      @emoji_enabled = false
      @emoji_map = DEFAULT_EMOJI_MAP.dup
      
      load_config
    end

    def toggle_emoji(enable = nil)
      return @emoji_enabled if enable.nil? && defined?(@emoji_enabled)
      
      @emoji_enabled = enable.nil? ? !@emoji_enabled : enable
      save_config
      # Clear cached formatted types since the formatting changed
      @emoji_formatted_types.clear
      @emoji_enabled
    end

    def emoji_enabled?
      @emoji_enabled
    end

    def format_commit_type(type)
      return type unless @emoji_enabled
      return type unless @emoji_map.key?(type)
      
      # Check cache first
      @emoji_formatted_types[type] ||= begin
        emoji = @emoji_map[type]
        "#{emoji} #{type}"
      end
    end

    def get_emoji_for_type(type)
      @emoji_map[type]
    end

    def list_emoji_mappings
      @emoji_map.map { |type, emoji| { type: type, emoji: emoji } }
    end

    def update_emoji_mapping(type, emoji)
      unless @emoji_map.key?(type)
        raise TemplateError, "Unknown commit type: #{type}"
      end

      @emoji_map[type] = emoji
      # Clear specific cached entry
      @emoji_formatted_types.delete(type)
      save_config
    end

    def reset_emoji_mappings
      @emoji_map = DEFAULT_EMOJI_MAP.dup
      # Clear all cached entries
      @emoji_formatted_types.clear
      save_config
    end

    private

    def load_config
      if File.exist?(CONFIG_FILE)
        begin
          load_existing_config
        rescue => e
          handle_config_error(e, "Failed to load")
          initialize_default_config
        end
      else
        initialize_default_config
      end
    end

    def load_existing_config
      config = YAML.load_file(CONFIG_FILE) || {}
      @emoji_map = config['emoji_map'] || DEFAULT_EMOJI_MAP.dup
      @emoji_enabled = !!config['emoji_enabled'] # Convert to boolean
    end

    def initialize_default_config
      @emoji_map = DEFAULT_EMOJI_MAP.dup
      @emoji_enabled = false
      save_config
    end

    def save_config
      config = {
        'emoji_map' => @emoji_map,
        'emoji_enabled' => @emoji_enabled
      }
      
      begin
        ensure_config_directory
        File.write(CONFIG_FILE, config.to_yaml)
      rescue => e
        handle_config_error(e, "Failed to save")
      end
    end

    def handle_config_error(error, action_description)
      warn "Warning: #{action_description} emoji config: #{error.message}"
      @emoji_map ||= DEFAULT_EMOJI_MAP.dup
      @emoji_enabled = false unless defined?(@emoji_enabled)
    end

    def ensure_config_directory
      config_dir = File.dirname(CONFIG_FILE)
      FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
    rescue Errno::EACCES => e
      warn "Warning: Permission denied creating config directory: #{e.message}"
    end
  end
end 