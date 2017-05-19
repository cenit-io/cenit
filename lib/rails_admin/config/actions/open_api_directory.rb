module RailsAdmin
  module Config
    module Actions

      class OpenApiDirectory < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          authorized? && User.current_super_admin?
        end

        register_instance_option :pjax? do
          true
        end

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            @model_config = RailsAdmin.config(Setup::ApiSpec)
            @objects = list_apis
          end
        end

        register_instance_option :link_icon do
          'fa fa-cube'
        end
      end

    end
  end
end