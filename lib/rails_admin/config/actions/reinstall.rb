module RailsAdmin
  module Config
    module Actions
      class Reinstall < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::CrossSharedCollection
        end


        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do
            @object.reinstall
            redirect_to back_or_index
          end
        end

        register_instance_option :link_icon do
          'icon-repeat'
        end
      end
    end
  end
end