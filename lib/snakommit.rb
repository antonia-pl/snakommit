# frozen_string_literal: true

# Load version first
require 'snakommit/version'

# Main module for the Snakommit application
module Snakommit
  class Error < StandardError; end
  
  # Returns the configuration directory path
  # @return [String] Path to configuration directory
  def self.config_dir
    File.join(ENV['HOME'] || Dir.home, '.snakommit')
  end
  
  # Returns the current version string
  # @return [String] Current version
  def self.version
    VERSION
  end
end

# Now require the rest of the modules
# Core functionality
require 'snakommit/config'
require 'snakommit/git'

# User interface
require 'snakommit/prompt'
require 'snakommit/cli'

# Extensions
require 'snakommit/performance'
require 'snakommit/templates'
require 'snakommit/hooks' 