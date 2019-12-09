module RailsAdmin
  module Config
    module Actions
      class Token < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          ::Cenit::OauthAccessGrant
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            ::Cenit::OauthAccessToken.for(
              @object.application_id,
              @object.scope,
              ::User.current
            )
            redirect_to rails_admin.show_path(model_name: @abstract_model.to_param, id: @object.id.to_s)
          end
        end

        register_instance_option :link_icon do
          'fa fa-key'
        end
      end
    end
  end
end