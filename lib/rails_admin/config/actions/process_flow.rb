module RailsAdmin
  module Config
    module Actions
      class ProcessFlow < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          false
        end

        register_instance_option :visible do
          authorized? && (flow = bindings[:object]) && (flow.nil_data_type || (flow.translator && flow.translator.type == :Import))
        end

        register_instance_option :only do
          Setup::Flow
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            if (@object.nil_data_type || (@object.translator && @object.translator.type == :Import))
              begin
                @object.process
                flash[:success] = "Flow #{@object.name} successfully processed"
              rescue Exception => ex
                flash[:error] = ex.message
              end
            else
              flash[:error] = "Can not process flow #{@object.name} without data type context"
            end

            redirect_to back_or_index
          end
        end

        register_instance_option :link_icon do
          'icon-play'
        end
      end
    end
  end
end
