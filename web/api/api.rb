#

require 'grape-swagger'
require 'helper/swagger'

module Hanlon
  module WebService
    class API < Grape::API
      mount ::Hanlon::WebService::Config::APIv1
      mount ::Hanlon::WebService::Boot::APIv1
      mount ::Hanlon::WebService::Image::APIv1
      mount ::Hanlon::WebService::Node::APIv1
      mount ::Hanlon::WebService::Model::APIv1
      mount ::Hanlon::WebService::VModel::APIv1
      mount ::Hanlon::WebService::Tag::APIv1
      mount ::Hanlon::WebService::Policy::APIv1
      mount ::Hanlon::WebService::Broker::APIv1
      mount ::Hanlon::WebService::ActiveModel::APIv1
      #if the service.yaml file includes the necessary configuration parameter (and it's
      # set to true), then make the swagger-ui-based documentation available as part of
      # the UI

      #if SERVICE_CONFIG[:config][:swagger_ui] && SERVICE_CONFIG[:config][:swagger_ui][:allow_access]
      if ProjectHanlon::Helper::Swagger.allow_swagger_access
        # first, grab a few parameters we'll need from the service.yaml file
        #mount_path = SERVICE_CONFIG[:config][:swagger_ui][:mount_path]
        #api_version = SERVICE_CONFIG[:config][:swagger_ui][:api_version]
        #config = ProjectHanlon::Config::Server.instance
        config = $config
        mount_path = config.sui_mount_path
        api_version = config.api_version

            # then make the call that retrieves the documentation and adds it to the UI
        add_swagger_documentation({ :mount_path => mount_path,
                                    :api_version => api_version,
                                    :hide_documentation_path => true,
                                  })
        # mount this after adding the swagger documentation so that this endpoint won't
        # show up in the swagger documentation (and mount this within the block if testing
        # for whether or not access to the swagger-ui-based documentation is allowed so
        # that this endpoint won't even appear in the UI unless the swagger documentation
        # is enabled)
        mount ::Hanlon::WebService::Swagger
      end
    end
  end
end
