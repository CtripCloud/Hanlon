require "json"

# Root ProjectHanlon namespace
module ProjectHanlon
  module VModelTemplate
    # Root VModel object
    # @abstract
    class Base < ProjectHanlon::Object
      include(ProjectHanlon::Logging)

      attr_accessor :name
      attr_accessor :label
      attr_accessor :description
      attr_accessor :hidden
      attr_accessor :callback
      attr_accessor :current_state
      attr_accessor :node_bound
      attr_accessor :final_state
      attr_accessor :counter
      attr_accessor :log
      attr_accessor :req_metadata_hash
      attr_accessor :firmware
      attr_accessor :bmc
      attr_accessor :raid
      attr_accessor :bios

      def update_self
        puts "----------"
        p self
        super
      end
      # init
      # @param hash [Hash]
      def initialize(hash)
        super()
        @name = "vmodel_base"
        @hidden = true
        @noun = "vmodel"
        @description = "Base vmodel template"
        @req_metadata_hash = {
          "@firmware" => {
            :default     => "false",
            :example     => "false",
            :required    => true,
            :description => "flag to indicate whether firmware need to be updated"
          },
          "@bmc" => {
            :default     => "",
            :example     => '{"enabled":"true"}',
            :required    => true,
            :description => "hash for ilo/bmc setting (JSON string)"
          },
          "@raid" => {
            :default     => "",
            :example     => '{"enabled":"true", "level":"raid1"}',
            :requied     => true,
            :description => "hash for RAID setting (JSON string)"
          },
          "@bios" => {
            :default     => "",
            :example     => '{"enabled":"true"}',
            :requied     => true,
            :description => "hash for bios setting (JSON string)"
          }
        }
        @firmware = nil
        @bmc = {}
        @raid = {}
        @bios = {}
        @callback = {}
        @current_state = :init
        @node = nil
        @policy_bound = nil
        @final_state = :nothing
        @counter = 0
        @result = nil
        # VModel Log
        @log = []
        @_namespace = :vmodel
        from_hash(hash) unless hash == nil
      end

      def callback_init(callback_namespace, args_array, node, policy_uuid)
        @args_array = args_array
        @node = node
        @policy_uuid = policy_uuid
        logger.debug "callback method called #{callback_namespace}"
        self.send(callback_namespace)
      end

      def fsm_tree
        # Overridden with custom tree within child vmodel
        {}
      end

      alias fsm fsm_tree

      def fsm_action(action, method)
        # We only change state if we have a node bound
        if @node
          old_state = @current_state
          old_state = :init unless old_state
          begin
            if fsm[@current_state][action] != nil
              @current_state = fsm[@current_state][action]
            else
              @current_state = fsm[@current_state][:else]
            end
          rescue => e
            logger.error "FSM ERROR: #{e.message}"
            raise e
          end

        else
          logger.debug "Action #{action} called with state #{@current_state} but no Node bound"
        end
        fsm_log(:state => @current_state,
                :old_state => old_state,
                :action => action,
                :method => method,
                :node_uuid => @node.uuid,
                :timestamp => Time.now.to_i)
      end

      def fsm_log(options)
        logger.debug "state update: #{options[:old_state]} => #{options[:state]} on #{options[:action]} for #{options[:node_uuid]}"
        options[:result] = @result
        options[:result] ||= "n/a"
        @log << options
        @result = nil
      end

      def node_metadata
        begin
          logger.debug "Building metadata"
          meta = {}
          logger.debug "Adding hanlon stuff"
          meta[:hanlon_tags] = @node.tags.join(',')
          meta[:hanlon_node_uuid] = @node.uuid
          meta[:hanlon_active_model_uuid] = @policy_uuid
          meta[:hanlon_vmodel_uuid] = @uuid
          meta[:hanlon_vmodel_name] = @name
          meta[:hanlon_vmodel_description] = @description
          meta[:hanlon_vmodel_template] = @name.to_s
          meta[:hanlon_policy_count] = @counter.to_s
          logger.debug "Finished metadata build"
        rescue => e
          logger.error "metadata error: #{e}"
        end
        meta
      end

      def callback_url(namespace, action)
        "#{api_svc_uri}/policy/callback/#{@policy_uuid}/#{namespace}/#{action}"
      end

      def print_header
        if @is_template
          return "Template Name", "Description"
        else
          return "Label", "Template", "Description", "UUID"
        end
      end

      def print_item
        if @is_template
          return @name.to_s, @description.to_s
        else
          firmware_str = @firmware || "n/a"
          bmc_str = @bmc || "n/a"
          raid_str = @raid || "n/a"
          bios_str = @bios || "n/a"
          return @label, @name.to_s, @description, @uuid, firmware_str, bmc_str, raid_str, bios_str
        end
      end

      def print_item_header
        if @is_template
          return "Template Name", "Description"
        else
          return "Label", "Template", "Description", "UUID", "Firmware", "RAID", "BIOS", "BMC"
        end
      end

      def print_items
        if @is_template
          return @name.to_s, @description.to_s
        else
          return @label, @name.to_s, @description, @uuid
        end
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end

      def config
        ProjectHanlon.config
      end

      def image_svc_uri
        "http://#{config.hanlon_server}:#{config.api_port}#{config.websvc_root}/image/#{@image_prefix}"
      end

      def api_svc_uri
        "http://#{config.hanlon_server}:#{config.api_port}#{config.websvc_root}"
      end

      def web_create_metadata(provided_metadata)
        missing_metadata = []
        rmd = req_metadata_hash
        rmd.each_key do
        |md|
          metadata = map_keys_to_symbols(rmd[md])
          provided_metadata = map_keys_to_symbols(provided_metadata)
          md = (!md.is_a?(Symbol) ? md.gsub(/^@/,'').to_sym : md)
          md_fld_name = '@' + md.to_s
          if provided_metadata[md]
            raise ProjectHanlon::Error::Slice::InvalidVModelMetadata, "Invalid Metadata [#{md.to_s}:'#{provided_metadata[md]}']" unless
                set_metadata_value(md_fld_name, provided_metadata[md])
          else
            if metadata[:default] != ""
              raise ProjectHanlon::Error::Slice::MissingVModelMetadata, "Missing metadata [#{md.to_s}]" unless
                  set_metadata_value(md_fld_name, metadata[:default])
            else
              raise ProjectHanlon::Error::Slice::MissingVModelMetadata, "Missing metadata [#{md.to_s}]" if metadata[:required]
            end
          end
        end
      end

      def cli_create_metadata
        puts "--- Building VModel (#{name}): #{label}\n".yellow
        req_metadata_hash.each_key { |key|
          metadata = map_keys_to_symbols(req_metadata_hash[key])
          key = key.to_sym if !key.is_a?(Symbol)
          flag = false
          until flag
            print "Please enter " + "#{metadata[:description]}".yellow.bold
            print " (example: " + "#{metadata[:example]}".yellow + ") \n"
            puts "default: " + "#{metadata[:default]}".yellow if metadata[:default] != ""
            puts metadata[:required] ? quit_option : skip_quit_option
            print " > "
            response = STDIN.gets.strip
            case response
              when "SKIP"
                if metadata[:required]
                  puts "Cannot skip, value required".red
                else
                  flag = true
                end
              when "QUIT"
                return false
              when ""
                if metadata[:default] != ""
                  flag = set_metadata_value(key, metadata[:default])
                else
                  puts "No default value, must enter something".red
                end
              else
                flag = set_metadata_value(key, response)
                puts "Value (".red + "#{response}".yellow + ") is invalid".red unless flag
            end
          end
        }
        true
      end

      def map_keys_to_symbols(hash)
        tmp = {}
        hash.each { |key, val|
          key = key.to_sym if !key.is_a?(Symbol)
          tmp[key] = val
        }
        tmp
      end

      def set_metadata_value(key, value)
        if value
          value = JSON.parse(value) if [:@bmc, :@raid, :@bios].include?(key)
          self.instance_variable_set(key.to_sym, value)
          true
        else
          false
        end
      end

      def skip_quit_option
        "(" + "SKIP".white + " to skip, " + "QUIT".red + " to cancel)"
      end

      def quit_option
        "(" + "QUIT".red + " to cancel)"
      end

      def mk_call(node, policy_uuid)
        @node, @policy_uuid = node, policy_uuid
      end

      def boot_call(node, policy_uuid)
        @node, @policy_uuid = node, policy_uuid
      end

    end
  end
end
