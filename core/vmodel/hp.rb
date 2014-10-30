require "erb"

# Root ProjectHanlon namespace
module ProjectHanlon
  module VModelTemplate
    # Root VModel object
    # @abstract
    class HP < ProjectHanlon::VModelTemplate::Base
      include(ProjectHanlon::Logging)

      def initialize(hash)
        super(hash)
        @hidden = false
        @name = 'hp generic'
        @description = "HP Generic Vendor Model"
        # State / must have a starting state
        @current_state = :vmodel_init
        @final_state = :vmodel_complete
        from_hash(hash) unless hash == nil
      end

      def callback
        {
          'firmware' => :firmware_call,
          'ilo'      => :ilo_call,
          'raid'     => :raid_call,
          'bios'     => :bios_call,
        }
      end

      def firmware_call
        @arg = @args_array.shift
        case @arg
          when "start"
            @result = "Acknowledged start to update firmware"
            fsm_action(:firmware_start, :firmware)
            return "ok"
          when "end"
            @result = "Acknowledged firmware update complete"
            fsm_action(:firmware_end, :firmware)
            return "ok"
          when "file"
            name = @args_array.pop
            if name
              @result = "Replied with file for firmware update: #{name}"
              fsm_action(:firmware_file, :firmware)
              return generate_file(name)
            else
              logger.error "file name can not be empty"
              return "error: request file without name"
            end
            return "ok"
          when "skip"
            @result = "Acknowledged skip firmware update"
            fsm_action(:firmware_skip, :firmware)
            return "ok"
          else
            return 'error'
        end
      end

      def ilo_call
        @arg = @args_array.shift
        case @arg
          when "start"
            @result = "Acknowledged start to config iLO"
            fsm_action(:ilo_start, :ilo)
            return "ok"
          when "end"
            @result = "Acknowledged iLO configuration complete"
            fsm_action(:ilo_end, :ilo)
            return "ok"
          when "file"
            name = @args_array.pop
            if name
              @result = "Replied with file for iLO configuration: #{name}"
              fsm_action(:ilo_file, :ilo)
              return generate_file(name)
            else
              logger.error "file name is nil"
              return "error: request file without name"
            end
          when "skip"
            @result = "acknowledged skip iLO configuration"
            fsm_action(:ilo_skip, :ilo)
            return "ok"
          else
            return 'error'
        end
      end

      def raid_call
        @arg = @args_array.shift
        case @arg
          when "start"
            @result = "Acknowledged start to config RAID"
            fsm_action(:raid_start, :raid)
            return "ok"
          when "end"
            @result = "Acknowledged RAID configuration complete "
            fsm_action(:raid_end, :raid)
            return "ok"
          when "file"
            name = @args_array.pop
            if name
              @result = "Replied with file for RAID configuration: #{name}"
              fsm_action(:raid_file, :raid)
              return generate_file(name)
            else
              logger.error "file name is nil"
              return "error: request file without file name"
            end
          when "skip"
            @result = "Acknowledged skip RAID configuration"
            fsm_action(:raid_skip, :raid)
            return "ok"
          else
            return 'error'
        end
      end

      def bios_call
        @arg = @args_array.shift
        case @arg
          when "start"
            @result = "Acknowledged start to config BIOS"
            fsm_action(:bios_start, :bios)
            return "ok"
          when "end"
            @result = "Acknowledged BIOS configuration complete"
            fsm_action(:bios_end, :bios)
            return "ok"
          when "file"
            name = @args_array.pop
            if name
              @result = "Replied with file for BIOS configuration: #{name}"
              fsm_action(:bios_file, :bios)
              return generate_file(name)
            else
              logger.error "file name is nil"
              return "error: request file without file name"
            end
          when "skip"
            @result = "Acknowledged skip BIOS configuration"
            fsm_action(:bios_skip, :bios)
            return "ok"
          else
            return 'error'
        end
      end

      # Defines our FSM for this vmodel
        #  For state => {action => state, ..}
      def fsm
        {
          :vmodel_init => {
            :mk_call         => :vmodel_init,
            :boot_call       => :vmodel_init,
            :firmware_start  => :firmware,
            :firmware_file   => :firmware,
            :firmware_end    => :ilo,
            :firmware_skip   => :ilo,
            :timeout         => :timeout_error,
            :error           => :error_catch,
            :else            => :vmodel_init
          },
          :firmware => {
            :mk_call         => :firmware,
            :boot_call       => :firmware,
            :firmware_start  => :firmware,
            :firmware_file   => :firmware,
            :firmware_end    => :ilo,
            :firmware_skip   => :ilo,
            :firmwaretimeout => :timeout_error,
            :error           => :error_catch,
            :else            => :firmware
          },
          :ilo => {
            :mk_call     => :ilo,
            :boot_call   => :ilo,
            :ilo_start   => :ilo,
            :ilo_file    => :ilo,
            :ilo_end     => :raid,
            :ilo_skip    => :raid,
            :ilo_timeout => :timeout_error,
            :error       => :error_catch,
            :else        => :ilo
          },
          :raid => {
            :mk_call      => :raid,
            :boot_call    => :raid,
            :raid_start   => :raid,
            :raid_file    => :raid,
            :raid_end     => :bios,
            :raid_skip    => :bios,
            :raid_timeout => :timeout_error,
            :error        => :error_catch,
            :else         => :raid
          },
          :bios => {
            :mk_call      => :bios,
            :boot_call    => :bios,
            :bios_start   => :bios,
            :bios_file    => :bios,
            :bios_end     => :vmodel_complete,
            :bios_skip    => :vmodel_complete,
            :bios_timeout => :timeout_error,
            :error        => :error_catch,
            :else         => :bios
          },
         :vmodel_complete => {
            :mk_call   => :vmodel_complete,
            :boot_call => :vmodel_complete,
            :else      => :vmodel_complete,
          },
          :timeout_error => {
            :mk_call   => :timeout_error,
            :boot_call => :timeout_error,
            :else      => :timeout_error,
            :reset     => :vmodel_init
          },
          :error_catch => {
            :mk_call   => :error_catch,
            :boot_call => :error_catch,
            :else      => :error_catch,
            :result    => :vmodel_init
          }
        }
      end

      # Defines our FSM Meta for this vmodel
      #  For state => {meta => value, ..}
      #  For 'file' meta, the first element in 'file' is an executable script which would be runned in MK
      def fsm_meta
        {
          :vmodel_init => {
            :max_time => 3600,
          },
          :firmware => {
            :max_time => 3600,
            :file => ["hpsum.sh"],
          },
          :ilo => {
            :max_time => 3600,
            :file => ["iloconf.sh", "ilotemp.xml"],
          },
          :raid => {
            :max_time => 3600,
            :file => ["raidconf.sh", "default-raid.ini"],
          },
          :bios => {
            :max_time => 3600,
            :file => ["biosconf.sh", "biostemp.xml", "conrep.xml"],
          },
        }
      end

      def mk_call(node, policy_uuid)
        super(node, policy_uuid)
        if node.last_state == 'idle'
          file_list = fsm_meta.fetch(@current_state, {})[:file]
          case @current_state
            when :vmodel_init
              # start vmodel from firmware phase
              file_list = fsm_meta.fetch(:firmware, {})[:file]
              ret = [:firmware, {'enabled' => @firmware, 'file' => file_list}]
              fsm_action(:mk_call, :mk_call)
            when :firmware
              ret = [:firmware, {'enabled' => @firmware, 'file' => file_list}]
            when :ilo
              ret = [:ilo, {'enabled' => @bmc["enabled"], 'file' => file_list}]
            when :raid
              ret = [:raid, {'enabled' => @raid["enabled"], 'file' => file_list}]
            when :bios
              ret = [:bios, {'enabled' => @bios["enabled"], 'file' => file_list}]
            else
              ret = [:acknowledged, {}]
          end
        else
          ret = [:acknowledged, {}]
        end
        ret
      end

      def boot_call(node, policy_uuid)
        super(node, policy_uuid)
        engine = ProjectHanlon::Engine.instance
        ret = engine.default_mk_boot(nood.uuid)
        fsm_action(:boot_call, :boot_call)
        ret
      end

      def template_filepath(filename)
        filepath = File.join(File.dirname(__FILE__), "hp/#{@node.attributes_hash['productname']}/#{filename}.erb")
        return filepath if File.exists?(filepath)
        filepath = File.join(File.dirname(__FILE__), "hp/#{filename}.erb")
        return filepath if File.exists?(filepath)
        raise ProjectHanlon::Error::Slice::InternalError, "template #{filename} can not found" unless filepath
      end

    end
  end
end
