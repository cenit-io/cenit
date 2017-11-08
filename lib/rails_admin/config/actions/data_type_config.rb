module RailsAdmin
  module Config
    module Actions
      class DataTypeConfig < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::DataType.class_hierarchy
        end

        register_instance_option :authorization_key do
          :config
        end

        register_instance_option :member do
          true
        end

        register_instance_option :route_fragment do
          'config'
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do

            data_type_config_model = RailsAdmin.config(Setup::DataTypeConfig).abstract_model

            if @object.config.new_record?
              hash = @object.config.share_hash
              hash.delete('_primary')
              token = Cenit::Token.create(data: hash.to_json, token_span: 300).token
              redirect_to rails_admin.new_path(model_name: data_type_config_model.to_param, params: { json_token: token })
            else
              redirect_to rails_admin.show_path(model_name: data_type_config_model.to_param, id: @object.config.id)
            end

          end
        end

        register_instance_option :link_icon do
          'fa fa-sliders'
        end
      end
    end
  end
end