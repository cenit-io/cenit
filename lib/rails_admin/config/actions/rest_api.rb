module RailsAdmin
  module Config
    module Actions
      class RestApi < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :link_icon do
          'icon-cog'
        end

        register_instance_option :controller do
          proc do

          end
        end
      end

    end
  end
end
