# frozen_string_literal: true

require 'snakommit/version'
require 'snakommit/config'
require 'snakommit/git'
require 'snakommit/prompt'
require 'snakommit/cli'

# Main module for the Snakommit application
module Snakommit
  class Error < StandardError; end
end 