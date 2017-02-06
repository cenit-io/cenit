module RailsAdmin
  module Config
    module Actions
      class Notebooks < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :link_icon do
          'fa fa-book'
        end

        register_instance_option :controller do
          proc do
          end
        end
      end

    end
  end
end
