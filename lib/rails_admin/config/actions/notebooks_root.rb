module RailsAdmin
  module Config
    module Actions
      class NotebooksRoot < RailsAdmin::Config::Actions::Base

        register_instance_option :root do
          true
        end

        register_instance_option :route_fragment do
          'notebooks'
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            render template: 'rails_admin/main/notebooks'
          end
        end

        register_instance_option :link_icon do
          'fa fa-book'
        end
      end
    end
  end
end
