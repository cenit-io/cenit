module RailsAdmin
  module Config
    module Actions
      class BaseGenerate < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Schema
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            begin
              Cenit::Actions.generate_data_types(@object || params[:bulk_ids])
            rescue Exception => ex
              do_flash(:error, 'Error generating data types:', ex.message)
            end
            redirect_to back_or_index
          end
        end

        register_instance_option :link_icon do
          'icon-cog'
        end

        register_instance_option :pjax? do
          false
        end
      end
    end
  end
end
