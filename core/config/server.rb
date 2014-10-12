require 'socket'
require 'fcntl'
require 'yaml'
require 'utility'
require 'logging/logger'

require 'config/common'

# This class represents the ProjectHanlon configuration. It is stored persistently in
# './web/config/hanlon_server.conf' and editing by the user

module ProjectHanlon
  module Config
    class Server
      include ProjectHanlon::Utility
      include ProjectHanlon::Logging
      include ProjectHanlon::Config::Common
      extend  ProjectHanlon::Logging

      attr_accessor :hanlon_server

      attr_accessor :persist_mode
      attr_accessor :persist_host
      attr_accessor :persist_port
      attr_accessor :persist_username
      attr_accessor :persist_password
      attr_accessor :persist_timeout

      attr_accessor :base_path
      attr_accessor :api_version
      attr_accessor :admin_port
      attr_accessor :api_port
      attr_accessor :hanlon_log_level

      attr_accessor :mk_checkin_interval
      attr_accessor :mk_checkin_skew

      # mk_log_level should be 'Logger::FATAL', 'Logger::ERROR', 'Logger::WARN',
      # 'Logger::INFO', or 'Logger::DEBUG' (default is 'Logger::ERROR')
      attr_accessor :mk_log_level
      attr_accessor :mk_tce_mirror
      attr_accessor :mk_tce_install_list_uri
      attr_accessor :mk_kmod_install_list_uri
      attr_accessor :mk_gem_mirror
      attr_accessor :mk_gemlist_uri
      attr_accessor :mk_nfs_server_ip


      attr_accessor :image_path

      attr_accessor :register_timeout
      attr_accessor :force_mk_uuid

      attr_accessor :daemon_min_cycle_time

      attr_accessor :node_expire_timeout

      attr_accessor :rz_mk_boot_debug_level
      attr_accessor :rz_mk_boot_kernel_args

      attr_accessor :sui_mount_path
      attr_accessor :sui_allow_access

      attr_reader   :noun

      # Obtain our defaults
      def defaults
        #base_path = SERVICE_CONFIG[:config][:swagger_ui][:base_path]
        #api_version = SERVICE_CONFIG[:config][:swagger_ui][:api_version]
        #default_websvc_root = "#{base_path}/#{api_version}"
        default_base_path = "/hanlon/api"
        default_image_path  = "#{$hanlon_root}/image"
        defaults = {
          'hanlon_server'            => get_an_ip,
          'persist_mode'             => :mongo,
          'persist_host'             => "127.0.0.1",
          'persist_port'             => 27017,
          'persist_username'         => '',
          'persist_password'         => '',
          'persist_timeout'          => 10,

          'base_path'                => default_base_path,
          'api_version'              => 'v1',
          'admin_port'               => 8025,
          'api_port'                 => 8026,

          'mk_checkin_interval'      => 60,
          'mk_checkin_skew'          => 5,
          'mk_log_level'             => "Logger::ERROR",
          'mk_gem_mirror'            => "http://localhost:2158/gem-mirror",
          'mk_gemlist_uri'           => "/gems/gem.list",
          'mk_tce_mirror'            => "http://localhost:2157/tinycorelinux",
          'mk_tce_install_list_uri'  => "/tce-install-list",
          'mk_kmod_install_list_uri' => "/kmod-install-list",
          'mk_nfs_server_ip'         => get_an_ip,

          'image_path'               => default_image_path,

          'register_timeout'         => 120,
          'force_mk_uuid'            => "",

          'daemon_min_cycle_time'    => 30,

          # this is the default value for the amount of time (in seconds) that
          # is allowed to pass before a node is removed from the system.  If the
          # node has not checked in for this long, it'll be removed
          'node_expire_timeout'      => 300,

          # DEPRECATED: use rz_mk_boot_kernel_args instead!
          # used to set the Microkernel boot debug level; valid values are
          # either the empty string (the default), "debug", or "quiet"
          'rz_mk_boot_debug_level'   => "Logger::ERROR",
          'hanlon_log_level'   => "Logger::ERROR",

          # used to pass arguments to the Microkernel's linux kernel;
          # e.g. "console=ttyS0" or "hanlon.ip=1.2.3.4"
          'rz_mk_boot_kernel_args'   => "",

          # config parameters for swagger_ui management (prefix::sui)
          'sui_mount_path'   => "/docs",
          'sui_allow_access'   => "true"
        }

        return defaults
      end

      def mk_fact_excl_pattern
        [
            "(^facter.*$)", "(^id$)", "(^kernel.*$)", "(^memoryfree$)","(^memoryfree_mb$)",
            "(^operating.*$)", "(^osfamily$)", "(^path$)", "(^ps$)",
            "(^ruby.*$)", "(^selinux$)", "(^ssh.*$)", "(^swap.*$)",
            "(^timezone$)", "(^uniqueid$)", "(^.*uptime.*$)","(.*json_str$)"
        ].join("|")
      end

    end
  end
end
