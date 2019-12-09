module RailsAdmin
  module Config
    module Actions
      class Access < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          ::Setup::Application
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            access_grant = Cenit::OauthAccessGrant.where(application_id_id: @object.application_id_id).first ||
              Cenit::OauthAccessGrant.create(application_id_id: @object.application_id_id, scope: 'read')

            redirect_to rails_admin.edit_path(model_name: Cenit::OauthAccessGrant.to_param, id: access_grant.id.to_s)
          end
        end

        register_instance_option :link_icon do
          'fa fa-key'
        end
      end
    end
  end
end