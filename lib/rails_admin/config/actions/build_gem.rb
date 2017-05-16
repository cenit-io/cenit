module RailsAdmin
  module Config
    module Actions
      class BuildGem < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::CrossSharedCollection
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do

            begin
              file_name, gem = Cenit::Actions.build_gem(@object)
              send_data gem, filename: file_name
            rescue Exception => ex
              flash[:error] = ex.message
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :pjax? do
          true
        end

        register_instance_option :link_icon do
          'icon-cog'
        end
      end
    end
  end
end