#

require 'json'
require 'api_utils'

module Hanlon
  module WebService
    module VModel

      class APIv1 < Grape::API

        version :v1, :using => :path, :vendor => "hanlon"
        format :json
        default_format :json
        SLICE_REF = ProjectHanlon::Slice::VModel.new([])

        rescue_from ProjectHanlon::Error::Slice::InvalidUUID,
                    ProjectHanlon::Error::Slice::MissingArgument,
                    ProjectHanlon::Error::Slice::InvalidVModelTemplate,
                    ProjectHanlon::Error::Slice::InvalidVModelMetadata,
                    ProjectHanlon::Error::Slice::MissingVModelMetadata,
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

        rescue_from ProjectHanlon::Error::Slice::InternalError do |e|
          Rack::Response.new(
              Hanlon::WebService::Response.new(500, e.class.name, e.message).to_json,
              500,
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

          def get_data_ref
            Hanlon::WebService::Utils::get_data
          end

          def slice_success_response(slice, command, response, options = {})
            Hanlon::WebService::Utils::rz_slice_success_response(slice, command, response, options)
          end

          def slice_success_object(slice, command, response, options = {})
            Hanlon::WebService::Utils::rz_slice_success_object(slice, command, response, options)
          end

        end

        resource :vmodel do

          # GET /vmodel
          # Query for defined vmodels.
          desc "Retrieve a list of all vmodel instances"
          get do
            vmodels = SLICE_REF.get_object("vmodels", :vmodel)
            slice_success_object(SLICE_REF, :get_all_vmodels, vmodels, :success_type => :generic)
          end     # end GET /vmodel

          # POST /vmodel
          # Create a Hanlon vmodel
          #   parameters:
          #     template          | String | The "template" to use for the new vmodel |         | Default: unavailable
          #     label             | String | The "label" to use for the new vmodel    |         | Default: unavailable
          #     req_metadata_hash | Hash   | The metadata to use for the new vmodel   |         | Default: unavailable
          desc "Create a new vmodel instance"
          params do
            requires "template", type: String, desc: "The vmodel template to use"
            requires "label", type: String, desc: "The new vmodel's label"
            requires "req_metadata_hash", type: Hash, desc: "The (JSON) metadata hash"
          end
          post do
            template = params["template"]
            label = params["label"]
            req_metadata_hash = params["req_metadata_hash"]
            # check the values that were passed in
            vmodel = SLICE_REF.get_vmodel_using_template_name(template)
            raise ProjectHanlon::Error::Slice::InvalidVModelTemplate, "Invalid VModel Template [#{template}] " unless vmodel
            # use the arguments passed in (above) to create a new vmodel
            raise ProjectHanlon::Error::Slice::MissingArgument, "Must Provide Required Metadata [req_metadata_hash]" unless req_metadata_hash
            vmodel.label = label
            vmodel.is_template = false
            vmodel.req_metadata_hash.each { |key, md_hash_value|
              value = params[key]
              vmodel.set_metadata_value(key, value)
            }
            vmodel.req_metadata_hash = req_metadata_hash
            get_data_ref.persist_object(vmodel)
            raise(ProjectHanlon::Error::Slice::CouldNotCreate, "Could not create VModel") unless vmodel
            slice_success_object(SLICE_REF, :create_vmodel, vmodel, :success_type => :created)
          end     # end POST /vmodel

          resource :templates do

            # GET /vmodel/templates
            # Query for available vmodel templates
            desc "Retrieve a list of available vmodel templates"
            get do
              # get the vmodel templates (as an array)
              vmodel_templates = SLICE_REF.get_child_templates(ProjectHanlon::VModelTemplate)
              # then, construct the response
              slice_success_object(SLICE_REF, :get_vmodel_templates, vmodel_templates, :success_type => :generic)
            end     # end GET /vmodel/templates

            resource '/:name' do

              # GET /vmodel/templates/{name}
              # Query for a specific vmodel template (by name)
              desc "Retrieve details for a specific vmodel template (by name)"
              params do
                requires :name, type: String, desc: "The vmodel template name"
              end
              get do
                # get the matching vmodel template
                vmodel_template_name = params[:name]
                vmodel_templates = SLICE_REF.get_child_templates(ProjectHanlon::VModelTemplate)
                vmodel_template = vmodel_templates.select { |template| template.name == vmodel_template_name }
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find VModel Template Named: [#{vmodel_template_name}]" unless vmodel_template && (vmodel_template.class != Array || vmodel_template.length > 0)
                # then, construct the response
                slice_success_object(SLICE_REF, :get_vmodel_template_by_uuid, vmodel_template[0], :success_type => :generic)
              end     # end GET /vmodel/templates/{uuid}

            end     # end resource /vmodel/templates/:uuid

          end     # end resource /vmodel/templates

          resource '/:uuid' do

            # GET /vmodel/{uuid}
            # Query for the state of a specific vmodel.
            desc "Retrieve details for a specific vmodel instance (by UUID)"
            params do
              requires :uuid, type: String, desc: "The vmodel's UUID"
            end
            get do
              vmodel_uuid = params[:uuid]
              vmodel = SLICE_REF.get_object("get_vmodel_by_uuid", :vmodel, vmodel_uuid)
              raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find VModel with UUID: [#{model_uuid}]" unless vmodel && (vmodel.class != Array || vmodel.length > 0)
              slice_success_object(SLICE_REF, :get_model_by_uuid, vmodel, :success_type => :generic)
            end     # end GET /vmodel/{uuid}

            # PUT /vmodel/{uuid}
            # Update a Hanlon vmodel (any of the the label or req_metadata_hash
            # can be updated using this endpoint; note that the vmodel template cannot be updated
            # once a vmodel is created
            #   parameters:
            #     label             | String | The "label" to use for the new vmodel    |         | Default: unavailable
            #     req_metadata_hash | Hash   | The metadata to use for the new vmodel   |         | Default: unavailable
            desc "Update a vmodel instance (by UUID)"
            params do
              requires :uuid, type: String, desc: "The vmodel's UUID"
              optional "label", type: String, desc: "The vmodel's new label"
              optional "req_metadata_hash", type: Hash, desc: "The new metadata hash"
            end
            put do
              # get the input parameters that were passed in as part of the request
              # (at least one of these should be a non-nil value)
              label = params["label"]
              req_metadata_hash = params["req_metadata_hash"]
              # get the UUID for the vmodel being updated
              vmodel_uuid = params[:uuid]
              # check the values that were passed in (and gather new meta-data if
              # the --change-metadata flag was included in the update command and the
              # command was invoked via the CLI...it's an error to use this flag via
              # the RESTful API, the req_metadata_hash should be used instead)
              vmodel = SLICE_REF.get_object("vmodel_with_uuid", :vmodel, vmodel_uuid)
              raise ProjectHanlon::Error::Slice::InvalidUUID, "Invalid VModel UUID [#{vmodel_uuid}]" unless vmodel && (vmodel.class != Array || vmodel.length > 0)
              vmodel.label = label if label
              if req_metadata_hash
                req_metadata_hash.each { |key, value|
                  value = req_metadata_hash[key]
                  vmodel.req_metadata_hash[key] = value
                }
              end
              raise ProjectHanlon::Error::Slice::CouldNotUpdate, "Could not update VModel [#{vmodel.uuid}]" unless vmodel.update_self
              slice_success_object(SLICE_REF, :update_vmodel, vmodel, :success_type => :updated)
            end     # end PUT /vmodel/{uuid}

            # DELETE /vmodel/{uuid}
            # Remove a Hanlon vmodel (by UUID)
            desc "Remove a vmodel instance (by UUID)"
            params do
              requires :uuid, type: String, desc: "The vmodel's UUID", desc: "The vmodel's UUID"
            end
            delete do
              vmodel_uuid = params[:uuid]
              vmodel = SLICE_REF.get_object("vmodel_with_uuid", :vmodel, vmodel_uuid)
              raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find VModel with UUID: [#{vmodel_uuid}]" unless vmodel && (vmodel.class != Array || vmodel.length > 0)
              raise ProjectHanlon::Error::Slice::CouldNotRemove, "Could not remove VModel [#{vmodel.uuid}]" unless get_data_ref.delete_object(vmodel)
              slice_success_response(SLICE_REF, :remove_model_by_uuid, "VModel [#{vmodel.uuid}] removed", :success_type => :removed)
            end     # end DELETE /vmodel/{uuid}

          end     # end resource /vmodel/:uuid

        end     # end resource /vmodel

      end

    end

  end

end
