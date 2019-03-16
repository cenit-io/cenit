module RailsAdmin
  module Config
    module Actions
      class RestApi2 < RailsAdmin::Config::Actions::Base

        register_instance_option :member do
          true
        end

        register_instance_option :i18n_key do
          :rest_api
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :link_icon do
          'icon-cog'
        end

        register_instance_option :controller do
          proc do
            render template: 'rails_admin/main/rest_api'
          end
        end
      end
    end
  end
end
