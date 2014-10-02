$config_file_path = "#{$app_root}/config/hanlon_#{$app_type}.conf"
$logging_path = "#{$app_root}/log/project_hanlon.log"
$temp_path = "#{$app_root}/tmp"

require 'object'
require 'diagnostics/tracer'
require 'diagnostics/loader'

Diagnostics::Loader.check_module('object', 'ProjectHanlon::Objectxe')

require 'config'
$config = ProjectHanlon::Config::Common.instance

module ProjectHanlon
  class Global

  end

  # Provide access to the global configuration for the project.
  def self.config
    $config
  end
end

require "set"
require "version"
require "object"
require "utility"
require "logging/logger"
require "error"
require "data"
require "config"
require "node"
require "policy"
require "engine"
require "slice"
require "persist"
require "model"
require "vmodel"
require "tagging"
require "policies"
require "image_service"
require "broker"
require "config/server"
require "config/client"

require 'helpers/object_patch'
