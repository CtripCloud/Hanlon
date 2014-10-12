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
          'bmc'      => :ilo_call,
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
          when "script"
            name = @args_array.pop
            if name
              @result = "Replied with script for firmware update: #{name}"
              fsm_action(:firmware_script, :firmware)
              return generate_script(name)
            else
              logger.error "script name is nil"
              return "error: request script without file name"
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
          when "script"
            name = @args_array.pop
            if name
              @result = "Replied with script for iLO configuration: #{name}"
              fsm_action(:ilo_script, :ilo)
              return generate_script(name)
            else
              logger.error "script name is nil"
              return "error: request script without file name"
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
          when "script"
            name = @args_array.pop
            if name
              @result = "Replied with script for RAID configuration: #{name}"
              fsm_action(:raid_script, :raid)
              return generate_script(name)
            else
              logger.error "script name is nil"
              return "error: request script without file name"
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
          when "script"
            name = @args_array.pop
            if name
              @result = "Replied with script for BIOS configuration: #{name}"
              fsm_action(:bios_script, :bios)
              return generate_script(name)
            else
              logger.error "script name is nil"
              return "error: request script without file name"
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
            :firmware_script => :firmware,
            :firmware_end    => :baking,
            :firmware_skip   => :baking,
            :timeout         => :timeout_error,
            :error           => :error_catch,
            :else            => :vmodel_init
          },
          :firmware => {
            :mk_call         => :firmware,
            :boot_call       => :firmware,
            :firmware_start  => :firmware,
            :firmware_script => :firmware,
            :firmware_end    => :baking,
            :firmware_skip   => :baking,
            :firmwaretimeout => :timeout_error,
            :error           => :error_catch,
            :else            => :firmware
          },
          :ilo => {
            :mk_call     => :ilo,
            :boot_call   => :ilo,
            :ilo_start   => :ilo,
            :ilo_script  => :ilo,
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
            :raid_script  => :raid,
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
            :bios_script  => :bios,
            :bios_end     => :vmodel_complete,
            :bios_skip    => :reset,
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
      #  For 'file' meta, the first element in the array is an executable script which would be runned in MK
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
            :file => ["raidconf.sh", "acu-e.ini", "cloud-raid.ini", "default-raid.ini"],
          },
          :bios => {
            :max_time => 3600,
            :file => ["biosconf.sh", "biostemp.xml", "conrep.xml", "rebootconf.sh"],
          },
        }
      end

      def mk_call(node, policy_uuid)
        super(node, policy_uuid)
        if node.last_state == 'idle'
          script_list = fsm_meta.fetch(@current_state, {})[:file]
          case @current_state
            when :vmodel_init
              # start vmodel from firmware phase
              script_list = fsm_meta.fetch(:firmware, {})[:file]
              ret = [:firmware, {'enabled' => @firmware, 'script' => script_list}]
              fsm_action(:mk_call, :mk_call)
            when :firmware
              ret = [:firmware, {'enabled' => @firmware, 'script' => script_list}]
            when :ilo
              ret = [:ilo, {'enabled' => @bmc["enabled"], 'script' => script_list}]
            when :raid
              ret = [:raid, {'enabled' => @raid["enabled"], 'script' => script_list}]
            when :bios
              ret = [:bios, {'enabled' => @bios["enabled"], 'script' => script_list}]
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
