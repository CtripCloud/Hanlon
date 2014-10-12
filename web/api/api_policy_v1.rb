#

require 'json'
require 'api_utils'

module Hanlon
  module WebService
    module Policy

      class APIv1 < Grape::API

        version :v1, :using => :path, :vendor => "hanlon"
        format :json
        default_format :json
        SLICE_REF = ProjectHanlon::Slice::Policy.new([])

        rescue_from ProjectHanlon::Error::Slice::InvalidUUID,
                    ProjectHanlon::Error::Slice::NoCallbackFound,
                    ProjectHanlon::Error::Slice::InvalidPolicyTemplate,
                    ProjectHanlon::Error::Slice::InvalidModel,
                    ProjectHanlon::Error::Slice::MissingTags,
                    ProjectHanlon::Error::Slice::InvalidMaximumCount,
                    ProjectHanlon::Error::Slice::MissingActiveModelUUID,
                    ProjectHanlon::Error::Slice::MissingCallbackNamespace,
                    ProjectHanlon::Error::Slice::MissingArgument,
                    ProjectHanlon::Error::Slice::InputError,
                    Grape::Exceptions::Validation do |e|
          Rack::Response.new(
              Hanlon::WebService::Response.new(400, e.class.name, e.message).to_json,
              400,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from ProjectHanlon::Error::Slice::CouldNotCreate,
                    ProjectHanlon::Error::Slice::CouldNotUpdate,
                    ProjectHanlon::Error::Slice::CouldNotRemove do |e|
          Rack::Response.new(
              Hanlon::WebService::Response.new(403, e.class.name, e.message).to_json,
              403,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from ProjectHanlon::Error::Slice::MethodNotAllowed do |e|
          Rack::Response.new(
              Hanlon::WebService::Response.new(405, e.class.name, e.message).to_json,
              405,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from :all do |e|
          #raise e
          Rack::Response.new(
              Hanlon::WebService::Response.new(500, e.class.name, e.message).to_json,
              500,
              { "Content-type" => "application/json" }
          )
        end

        helpers do

          def content_type_header
            settings[:content_types][env['api.format']]
          end

          def api_format
            env['api.format']
          end

          def is_uuid?(string_)
            string_ =~ /^[A-Za-z0-9]{1,22}$/
          end

          def request_is_from_hanlon_subnet(ip_addr)
            Hanlon::WebService::Utils::request_from_hanlon_subnet?(ip_addr)
          end

          def get_data_ref
            Hanlon::WebService::Utils::get_data
          end

          def slice_success_response(slice, command, response, options = {})
            Hanlon::WebService::Utils::rz_slice_success_response(slice, command, response, options)
          end

          def slice_success_object(slice, command, response, options = {})
            Hanlon::WebService::Utils::rz_slice_success_object(slice, command, response, options)
          end

          def make_callback(active_model, callback_namespace, command_array)
            if active_model.vmodel && active_model.vmodel.current_state != active_model.vmodel.final_state
              model = active_model.vmodel
            else
              model = active_model.model
            end
            callback = model.callback[callback_namespace]
            raise ProjectHanlon::Error::Slice::NoCallbackFound, "Missing callback" unless callback
            node = get_data_ref.fetch_object_by_uuid(:node, active_model.node_uuid)
            callback_return = model.callback_init(callback, command_array, node, active_model.uuid, active_model.broker)
            active_model.update_self
            callback_return
          end

        end

        resource :policy do

          # GET /policy
          # Query for defined policies.
          desc "Retrieve a list of all policy instances"
          get do
            policies = SLICE_REF.get_object("policies", :policy)
            slice_success_object(SLICE_REF, :get_all_policies, policies, :success_type => :generic)
          end     # end GET /policy

          # POST /policy
          # Create a Hanlon policy
          #   parameters:
          #     template          | String | The "template" to use for the new policy |         | Default: unavailable
          #     label             | String | The "label" to use for the new policy    |         | Default: unavailable
          #     vmodel_uuid       | String | The UUID of the vmodel to use            |         | Default: unavailable
          #     model_uuid        | String | The UUID of the model to use             |         | Default: unavailable
          #     tags              | String | The (comma-separated) list of tags       |         | Default: unavailable
          #     broker_uuid       | String | The UUID of the broker to use            |         | Default: "none"
          #     enabled           | String | A flag indicating if policy is enabled   |         | Default: "false"
          #     maximum           | String | The maximum_count for the policy         |         | Default: "0"
          desc "Create a new policy instance"
          params do
            requires "template", type: String, desc: "The policy template to use"
            requires "label", type: String, desc: "The new policy's name"
            requires "vmodel_uuid", type: String, desc: "The vmodel to use (by UUID)"
            requires "model_uuid", type: String, desc: "The model to use (by UUID)"
            requires "tags", type: String, desc: "The tags to match against"
            optional "broker_uuid", type: String, default: "none", desc: "The broker to use (by UUID)"
            optional "enabled", type: String, default: "false", desc: "Enabled when created?"
            optional "maximum", type: String, default: "0", desc: "Max. number to match against"
          end
          post do
            # grab values for required parameters
            policy_template = params["template"]
            label = params["label"]
            vmodel_uuid = params["vmodel_uuid"]
            model_uuid = params["model_uuid"]
            broker_uuid = params["broker_uuid"] unless params["broker_uuid"] == "none"
            tags = params["tags"]
            enabled = params["enabled"]
            maximum = params["maximum"]
            # check for errors in inputs
            policy = SLICE_REF.new_object_from_template_name(POLICY_PREFIX, policy_template)
            raise ProjectHanlon::Error::Slice::InvalidPolicyTemplate, "Policy Template is not valid [#{policy_template}]" unless policy
            vmodel = SLICE_REF.get_object("vmodel_by_uuid", :vmodel, vmodel_uuid)
            model = SLICE_REF.get_object("model_by_uuid", :model, model_uuid)
            raise ProjectHanlon::Error::Slice::InvalidUUID, "Invalid Model UUID [#{model_uuid}]" unless model && (model.class != Array || model.length > 0)
            raise ProjectHanlon::Error::Slice::InvalidModel, "Invalid Model Type [#{model.template}] != [#{policy.template}]" unless policy.template.to_s == model.template.to_s
            if broker_uuid
              raise ProjectHanlon::Error::Slice::InputError, "Cannot add a broker to a 'noop' policy" if ["boot_local", "discover_only"].include?(policy_template)
              broker = SLICE_REF.get_object("broker_by_uuid", :broker, broker_uuid)
              raise ProjectHanlon::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{broker_uuid}]" unless (broker && (broker.class != Array || broker.length > 0)) || broker_uuid == "none"
            end
            tags = tags.split(",") unless tags.class.to_s == "Array"
            raise ProjectHanlon::Error::Slice::MissingTags, "Must provide at least one tag ['tag(,tag)']" unless tags.count > 0
            raise ProjectHanlon::Error::Slice::InvalidMaximumCount, "Policy maximum count must be a valid integer" unless maximum.to_i.to_s == maximum
            raise ProjectHanlon::Error::Slice::InvalidMaximumCount, "Policy maximum count must be > 0" unless maximum.to_i >= 0
            # Flesh out the policy
            policy.label         = label
            policy.vmodel        = vmodel
            policy.model         = model
            policy.broker        = broker
            policy.tags          = tags
            policy.enabled       = enabled
            policy.is_template   = false
            policy.maximum_count = maximum
            # Add policy
            policy_rules         = ProjectHanlon::Policies.instance
            raise(ProjectHanlon::Error::Slice::CouldNotCreate, "Could not create Policy") unless policy_rules.add(policy)
            slice_success_object(SLICE_REF, :create_policy, policy, :success_type => :created)
          end     # end POST /policy

          resource :templates do

            # GET /policy/templates
            # Query for available policy templates
            desc "Retrieve a list of available policy templates"
            get do
              # get the policy templates (as an array)
              policy_templates = SLICE_REF.get_child_templates(ProjectHanlon::PolicyTemplate)
              # then, construct the response
              slice_success_object(SLICE_REF, :get_policy_templates, policy_templates, :success_type => :generic)
            end     # end GET /policy/templates

            resource '/:name' do

              # GET /policy/templates/{name}
              # Query for a specific policy template (by UUID)
              desc "Retrieve details for a specific policy template (by name)"
              params do
                requires :name, type: String, desc: "The name of the template"
              end
              get do
                # get the matching policy template
                policy_template_name = params[:name]
                policy_templates = SLICE_REF.get_child_templates(ProjectHanlon::PolicyTemplate)
                policy_template = policy_templates.select { |template| template.template.to_s == policy_template_name }
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Policy Template Named: [#{policy_template_name}]" unless policy_template && (policy_template.class != Array || policy_template.length > 0)
                # then, construct the response
                slice_success_object(SLICE_REF, :get_policy_template_by_name, policy_template[0], :success_type => :generic)
              end     # end GET /policy/templates/{name}

            end     # end resource /policy/templates/:name

          end     # end resource /policy/templates

          # the following description hides this endpoint from the swagger-ui-based documentation
          # (since the functionality provided by this endpoint is not intended to be used off of
          # the Hanlon server)
          desc 'Hide this endpoint', {
              :hidden => true
          }

          resource :callback do
            resource :vmodel do
              resource '/:namespace_and_args', requirements: { namespace_and_args: /.*/ } do
                desc "Used to handle vmodel callbacks (to active_model instances)"
                before do
                  # only allow access to this resource from the Hanlon subnet
                  unless request_is_from_hanlon_subnet(env['REMOTE_ADDR'])
                    env['api.format'] = :text
                    raise ProjectHanlon::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /policy/callback resource is not allowed from outside of the Hanlon subnet"
                  end
                end
                params do
                  requires :namespace_and_args, type: String, desc: "The namespace and arguments for the callback"
                  requires :uuid, type: String, desc: "The UUID for the node"
                  optional :mac_id, type: String, desc: "The MAC addresses of the node's NICs."
                  optional :name, type: String, desc: "The name of vmodel script."
                end
                get do
                  node_uuid = params[:uuid].upcase if params[:uuid]
                  mac_id = params[:mac_id].upcase.split("_") if params[:mac_id]
                  raise ProjectHanlon::Error::Slice::MissingArgument, "At least one of the optional arguments (uuid or mac_id) must be specified" unless ((node_uuid && node_uuid.length > 0) || (mac_id && !(mac_id.empty?)))
                  mac_id.collect! {|x| x.upcase.gsub(':', '') } if mac_id
                  namespace_and_args = params[:namespace_and_args].split('/')
                  callback_namespace = namespace_and_args.shift
                  raise ProjectHanlon::Error::Slice::MissingCallbackNamespace, "Missing callback namespace" unless SLICE_REF.validate_arg(callback_namespace)
                  namespace_and_args << params[:name] if params[:name]
                  engine       = ProjectHanlon::Engine.instance
                  active_model = nil
                  engine.get_active_models.each { |am| active_model = am if am.node_uuid == node_uuid }
                  raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Active Model with Node UUID: [#{node_uuid}]" unless active_model
                  env['api.format'] = :text
                  make_callback(active_model, callback_namespace, namespace_and_args)
                end
              end     # end resource /policy/callback/vmodel/:namespace_and_args
            end

            resource '/:uuid' do

              resource '/:namespace_and_args', requirements: { namespace_and_args: /.*/ } do

                # GET /policy/callback/{uuid}/{namespace_and_args}
                # Make a callback "call" (used during the install/broker-handoff process to track progress)
                desc "Used to handle callbacks (to active_model instances)"
                before do
                  # only allow access to this resource from the Hanlon subnet
                  unless request_is_from_hanlon_subnet(env['REMOTE_ADDR'])
                    env['api.format'] = :text
                    raise ProjectHanlon::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /policy/callback resource is not allowed from outside of the Hanlon subnet"
                  end
                end
                params do
                  requires :uuid, type: String, desc: "The active_model's UUID"
                  requires :namespace_and_args, type: String, desc: "The namespace and arguments for the callback"
                end
                get do
                  # get (and check) the required parameters
                  active_model_uuid  = params[:uuid]
                  raise ProjectHanlon::Error::Slice::MissingActiveModelUUID, "Missing active model uuid" unless SLICE_REF.validate_arg(active_model_uuid)
                  namespace_and_args = params[:namespace_and_args].split('/')
                  callback_namespace = namespace_and_args.shift
                  raise ProjectHanlon::Error::Slice::MissingCallbackNamespace, "Missing callback namespace" unless SLICE_REF.validate_arg(callback_namespace)
                  engine       = ProjectHanlon::Engine.instance
                  active_model = nil
                  engine.get_active_models.each { |am| active_model = am if am.uuid == active_model_uuid }
                  raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{active_model_uuid}]" unless active_model
                  env['api.format'] = :text
                  make_callback(active_model, callback_namespace, namespace_and_args)
                end     # end GET /policy/callback/{uuid}/{namespace_and_args}

              end     # end resource /policy/callback/:uuid/:namespace_and_args

            end     # end resource /policy/callback/:uuid

          end     # end resource /policy/callback

          resource '/:uuid' do

            # GET /policy/{uuid}
            # Query for the state of a specific policy.
            desc "Retrieve details for a specific policy instance (by UUID)"
            params do
              requires :uuid, type: String, desc: "The policy's UUID"
            end
            get do
              policy_uuid = params[:uuid]
              policy = SLICE_REF.get_object("get_policy_by_uuid", :policy, policy_uuid)
              raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{policy_uuid}]" unless policy && (policy.class != Array || policy.length > 0)
              slice_success_object(SLICE_REF, :get_policy_by_uuid, policy, :success_type => :generic)
            end     # end GET /policy/{uuid}

            # PUT /policy/{uuid}
            # Update a Hanlon policy (any of the the label, image UUID, or req_metadata_hash
            # can be updated using this endpoint; note that the policy template cannot be updated
            # once a policy is created
            #   parameters:
            #     label             | String | The new "label" value                    |         | Default: unavailable
            #     vmodel_uuid       | String | The new vmodel UUID value                |         | Default: unavailable
            #     model_uuid        | String | The new model UUID value                 |         | Default: unavailable
            #     tags              | String | The new (comma-separated) list of tags   |         | Default: unavailable
            #     broker_uuid       | String | The new broker UUID value                |         | Default: unavailable
            #     new_line_number   | String | The new line number in the policy table  |         | Default: unavailable
            #     enabled           | String | A new "enabled flag" value               |         | Default: unavailable
            #     maximum           | String | The new maximum_count value              |         | Default: unavailable
            desc "Update a policy instance (by UUID)"
            params do
              requires :uuid, type: String, desc: "The policy's UUID"
              optional "label", type: String, default: nil, desc: "The policy's new label"
              optional "vmodel_uuid", type: String, default: nil, desc: "The new vmodel (by UUID)"
              optional "model_uuid", type: String, default: nil, desc: "The new model (by UUID)"
              optional "tags", type: String, default: nil, desc: "The new tags"
              optional "broker_uuid", type: String, default: nil, desc: "The new broker (by UUID)"
              optional "new_line_number", type: String, default: nil, desc: "Line number (in policy table)"
              optional "enabled", type: String, default: nil, desc: "The new 'enabled' flag value"
              optional "maximum", type: String, default: nil, desc: "Max. number to match against"
            end
            put do
              # get optional parameters
              label = params["label"]
              vmodel_uuid = params["vmodel_uuid"]
              model_uuid = params["model_uuid"]
              tags = params["tags"]
              broker_uuid = params["broker_uuid"]
              new_line_number = params["new_line_number"]
              enabled = params["enabled"]
              maximum = params["maximum"]

              # and check the values that were passed in (skipping those that were not)
              policy_uuid = params[:uuid]
              policy = SLICE_REF.get_object("policy_with_uuid", :policy, policy_uuid)
              raise ProjectHanlon::Error::Slice::InvalidUUID, "Invalid Policy UUID [#{policy_uuid}]" unless policy && (policy.class != Array || policy.length > 0)

              if tags
                tags = tags.split(",") if tags.is_a? String
                raise ProjectHanlon::Error::Slice::MissingArgument, "Policy Tags ['tag(,tag)']" unless tags.count > 0
              end
              vmodel = nil
              if vmodel_uuid
                vmodel = SLICE_REF.get_object("vmodel_by_uuid", :vmodel, vmodel_uuid)
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Invalid VModel UUID [#{vmodel_uuid}]" unless vmodel && (vmodel.class != Array || vmodel.length > 0)
              end
              model = nil
              if model_uuid
                model = SLICE_REF.get_object("model_by_uuid", :model, model_uuid)
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Invalid Model UUID [#{model_uuid}]" unless model && (model.class != Array || model.length > 0)
                raise ProjectHanlon::Error::Slice::InvalidModel, "Invalid Model Type [#{model.label}]" unless policy.template == model.template
              end
              broker = nil
              if broker_uuid
                raise ProjectHanlon::Error::Slice::InputError, "Cannot add a broker to a 'noop' policy" if [:boot_local, :discover_only].include?(policy.template)
                broker = SLICE_REF.get_object("broker_by_uuid", :broker, broker_uuid)
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{broker_uuid}]" unless (broker && (broker.class != Array || broker.length > 0)) || broker_uuid == "none"
              end
              new_line_number = (new_line_number ? new_line_number.strip : nil)
              raise ProjectHanlon::Error::Slice::InputError, "New index '#{new_line_number}' is not an integer" if new_line_number && !/^[+-]?\d+$/.match(new_line_number)
              if enabled
                raise ProjectHanlon::Error::Slice::InputError, "Enabled flag must have a value of 'true' or 'false'" if enabled != "true" && enabled != "false"
              end
              if maximum
                raise ProjectHanlon::Error::Slice::InvalidMaximumCount, "Policy maximum count must be a valid integer" unless maximum.to_i.to_s == maximum
                raise ProjectHanlon::Error::Slice::InvalidMaximumCount, "Policy maximum count must be > 0" unless maximum.to_i >= 0
              end
              # Update object properties
              policy.label = label if label
              policy.vmodel = vmodel if vmodel
              policy.model = model if model
              policy.broker = broker if broker
              policy.tags = tags if tags
              policy.enabled = enabled if enabled
              policy.maximum_count = maximum if maximum
              if new_line_number
                policy_rules = ProjectHanlon::Policies.instance
                policy_rules.move_policy_to_idx(policy.uuid, new_line_number.to_i)
              end
              # Update object
              raise ProjectHanlon::Error::Slice::CouldNotUpdate, "Could not update Broker Target [#{broker.uuid}]" unless policy.update_self
              slice_success_object(SLICE_REF, :update_policy, policy, :success_type => :updated)
            end     # end PUT /policy/{uuid}

            # DELETE /policy/{uuid}
            # Remove a Hanlon policy (by UUID)
            desc "Remove a model instance (by UUID)"
            params do
              requires :uuid, type: String, desc: "The policy's UUID"
            end
            delete do
              policy_uuid = params[:uuid]
              policy = SLICE_REF.get_object("policy_with_uuid", :policy, policy_uuid)
              raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{policy_uuid}]" unless policy && (policy.class != Array || policy.length > 0)
              raise ProjectHanlon::Error::Slice::CouldNotRemove, "Could not remove Policy [#{policy.uuid}]" unless get_data_ref.delete_object(policy)
              slice_success_response(SLICE_REF, :remove_policy_by_uuid, "Policy [#{policy.uuid}] removed", :success_type => :removed)
            end     # end DELETE /policy/{uuid}

          end     # end resource /policy/:uuid

        end     # end resource /policy

      end

    end

  end

end
