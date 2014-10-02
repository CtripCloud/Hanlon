require 'json'
require 'vmodel/base'

# Root ProjectHanlon namespace
module ProjectHanlon
  class Slice

    # ProjectHanlon Slice VModel
    class VModel < ProjectHanlon::Slice

      # Root namespace for vmodel objects; used to find them
      # in object space in order to gather meta-data for creating vmodels
      SLICE_VMODEL_PREFIX = "ProjectHanlon::VModelTemplate::"

      # Initializes ProjectHanlon::Slice::VModel including #slice_commands, #slice_commands_help
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @uri_string = ProjectHanlon.config.hanlon_uri + ProjectHanlon.config.websvc_root + '/vmodel'
      end

      def slice_name
        'vmodel'
      end

      def slice_commands
        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices)
        commands = get_command_map(
            "vmodel_help",
            "get_all_vmodels",
            "get_vmodel_by_uuid",
            "add_vmodel",
            "update_vmodel",
            "remove_all_vmodels",
            "remove_vmodel_by_uuid")
        # and add any additional commands specific to this slice
        commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
        commands[:get][:else] = "get_vmodel_by_uuid"
        commands[:get][[/^(temp|template|templates|types)$/]] = "get_all_templates"

        commands
      end

      def all_command_option_data
        {
            :add => [
                { :name        => :template,
                  :default     => false,
                  :short_form  => '-t',
                  :long_form   => '--template VMODEL_TEMPLATE',
                  :description => 'The vmodel template to use for the new vmodel.',
                  :uuid_is     => 'not_allowed',
                  :required    => true
                },
                { :name        => :label,
                  :default     => false,
                  :short_form  => '-l',
                  :long_form   => '--label VMODEL_LABEL',
                  :description => 'The label to use for the new vmodel.',
                  :uuid_is     => 'not_allowed',
                  :required    => true
                }
            ],
            :update => [
                { :name        => :label,
                  :default     => false,
                  :short_form  => '-l',
                  :long_form   => '--label VMODEL_LABEL',
                  :description => 'The new label to use for the vmodel.',
                  :uuid_is     => 'required',
                  :required    => true
                },
                { :name        => :change_metadata,
                  :default     => false,
                  :short_form  => '-c',
                  :long_form   => '--change-metadata',
                  :description => 'Used to trigger a change in the vmodel\'s meta-data',
                  :uuid_is     => 'required',
                  :required    => true
                }
            ]
        }.freeze
      end

      def vmodel_help
        if @prev_args.length > 1
          command = @prev_args.peek(1)
          begin
            # load the option items for this command (if they exist) and print them
            option_items = command_option_data(command)
            print_command_help(command, option_items)
            return
          rescue
          end
        end
        # if here, then either there are no specific options for the current command or we've
        # been asked for generic help, so provide generic help
        puts get_vmodel_help
      end

      def get_vmodel_help
        return ["VModel Slice: used to add, view, update, and remove vmodels.".red,
                "VModel Commands:".yellow,
                "\thanlon vmodel [get] [all]                 " + "View all vmodels".yellow,
                "\thanlon vmodel [get] (UUID)                " + "View specific vmodel instance".yellow,
                "\thanlon vmodel [get] template|templates    " + "View list of vmodel templates".yellow,
                "\thanlon vmodel add (options...)            " + "Create a new vmodel instance".yellow,
                "\thanlon vmodel update (UUID) (options...)  " + "Update a specific vmodel instance".yellow,
                "\thanlon vmodel remove (UUID)|all           " + "Remove existing vmodel(s)".yellow,
                "\thanlon vmodel --help                      " + "Display this screen".yellow].join("\n")
      end

      def get_all_vmodels
        @command = :get_all_vmodels
        uri = URI.parse @uri_string
        vmodel_array = hash_array_to_obj_array(expand_response_with_uris(hnl_http_get(uri)))
        print_object_array(vmodel_array, "VModels:", :style => :table)
      end

      def get_vmodel_by_uuid
        @command = :get_vmodel_by_uuid
        # the UUID is the first element of the @command_array
        vmodel_uuid = @command_array.first
        # setup the proper URI depending on the options passed in
        uri = URI.parse(@uri_string + '/' + vmodel_uuid)
        # and get the results of the appropriate RESTful request using that URI
        include_http_response = true
        result, response = hnl_http_get(uri, include_http_response)
        if response.instance_of?(Net::HTTPBadRequest)
          raise ProjectHanlon::Error::Slice::CommandFailed, result["result"]["description"]
        end
        # finally, based on the options selected, print the results
        print_object_array(hash_array_to_obj_array([result]), "VModel:")
      end

      def get_all_templates
        @command = :get_all_templates
        # get the list of model templates nd print it
        uri = URI.parse @uri_string + '/templates'
        vmodel_templates = hash_array_to_obj_array(expand_response_with_uris(hnl_http_get(uri)))
        print_object_array(vmodel_templates, "VModel Templates:")
      end

      def add_vmodel
        @command = :add_vmodel
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = command_option_data(:add)
        command_hash = Hash[*@command_array]
        template_name = command_hash["-t"] || command_hash["--template"]
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "hanlon vmodel add (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "add"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        template = options[:template]
        label = options[:label]
        # use the arguments passed in to create a new vmodel
        vmodel = get_vmodel_using_template_name(options[:template])
        raise ProjectHanlon::Error::Slice::InputError, "Invalid vmodel template [#{options[:template]}] " unless vmodel
        vmodel.cli_create_metadata
        # setup the POST (to create the requested policy) and return the results
        uri = URI.parse @uri_string
        body_hash = {
            "template" => template,
            "label" => label,
            "req_metadata_hash" => vmodel.req_metadata_hash
        }
        vmodel.req_metadata_hash.each { |key, md_hash_value|
          value = vmodel.instance_variable_get(key)
          body_hash[key] = value
        }
        json_data = body_hash.to_json
        puts uri, json_data
        result, response = hnl_http_post_json_data(uri, json_data, true)
        if response.instance_of?(Net::HTTPBadRequest)
          raise ProjectHanlon::Error::Slice::CommandFailed, result["result"]["description"]
        end
        print_object_array(hash_array_to_obj_array([result]), "VModel Created:")
      end

      def update_vmodel
        # TODO update do not work properly
        @command = :update_vmodel
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = command_option_data(:update)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        vmodel_uuid, options = parse_and_validate_options(option_items, "hanlon vmodel update UUID (options...)", :require_one)
        includes_uuid = true if vmodel_uuid
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        label = options[:label]
        change_metadata = options[:change_metadata]
        # now, use the values that were passed in to update the indicated vmodel
        uri = URI.parse(@uri_string + '/' + vmodel_uuid)
        # and get the results of the appropriate RESTful request using that URI
        include_http_response = true
        result, response = hnl_http_get(uri, include_http_response)
        if response.instance_of?(Net::HTTPBadRequest)
          raise ProjectHanlon::Error::Slice::CommandFailed, result["result"]["description"]
        end
        vmodel = hash_to_obj(result)
        # if the user requested a change to the meta-data hash associated with the
        # indicated vmodel, then gather that new meta-data from the user
        if change_metadata
          raise ProjectHanlon::Error::Slice::UserCancelled, "User cancelled VModel creation" unless
              vmodel.cli_create_metadata
        end
        # add properties passed in from command line to the json_data
        # hash that we'll be passing in as the body of the request
        body_hash = {}
        body_hash["label"] = label if label
        if change_metadata
          vmodel.req_metadata_hash.each { |key, md_hash_value|
            value = vmodel.instance_variable_get(key)
            body_hash[key] = value
          }
          body_hash["req_metadata_hash"] = vmodel.req_metadata_hash
        end
        json_data = body_hash.to_json
        # setup the PUT (to update the indicated policy) and return the results
        result, response = hnl_http_put_json_data(uri, json_data, true)
        if response.instance_of?(Net::HTTPBadRequest)
          raise ProjectHanlon::Error::Slice::CommandFailed, result["result"]["description"]
        end
        print_object_array(hash_array_to_obj_array([result]), "VModel Updated:")
      end

      def remove_all_vmodels
        @command = :remove_all_vmodels
        raise ProjectHanlon::Error::Slice::MethodNotAllowed, "This method has been deprecated"
      end

      def remove_vmodel_by_uuid
        @command = :remove_vmodel_by_uuid
        # the UUID was the last "previous argument"
        vmodel_uuid = get_uuid_from_prev_args
        # setup the DELETE (to remove the indicated vmodel) and return the results
        uri = URI.parse @uri_string + "/#{vmodel_uuid}"
        result, response = hnl_http_delete(uri, true)
        if response.instance_of?(Net::HTTPBadRequest)
          raise ProjectHanlon::Error::Slice::CommandFailed, result["result"]["description"]
        end
        slice_success(result, :success_type => :removed)
      end

      def get_vmodel_using_template_name(template_name)
        get_child_types(SLICE_VMODEL_PREFIX).each { |template|
          return template if template.name.to_s == template_name
        }
        nil
      end

    end

    # Alias ProjectHanlon::Slice::Vmodel to ProjectHanlon::Slice::VModel
    Vmodel = VModel
  end
end
