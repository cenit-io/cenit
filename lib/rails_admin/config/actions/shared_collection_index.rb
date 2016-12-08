module RailsAdmin
  module Config
    module Actions
      class SharedCollectionIndex < RailsAdmin::Config::Actions::Base

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            redirect_to rails_admin.index_path(model_name: Setup::CrossSharedCollection.to_s.underscore.gsub('/', '~'))
          end
        end

        register_instance_option :link_icon do
          'fa fa-cube'
        end
      end
    end
  end
end
