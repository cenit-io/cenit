module RailsAdmin
  module Config
    module Actions
      class StoreIndex < RailsAdmin::Config::Actions::Base

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            redirect_to rails_admin.index_path(model_name: Setup::CrossSharedCollection.to_s.underscore.gsub('/', '~'), 'f' => {'category' => {'73891' => {'v' => 'store'}}} )
          end
        end

        register_instance_option :link_icon do
          'fa fa-shopping-basket'
        end
      end
    end
  end
end
