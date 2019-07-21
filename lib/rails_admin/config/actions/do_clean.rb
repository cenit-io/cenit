module RailsAdmin
  module Config
    module Actions
      class DoClean < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          ::Cenit::ActiveTenant
        end

        register_instance_option :pjax? do
          true
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            ::Cenit::ActiveTenant.clean
            redirect_to back_or_index
          end
        end

        register_instance_option :link_icon do
          'icon-trash'
        end

        def template_name
          :trash
        end
      end
    end
  end
end