module RailsAdmin
  module Config
    module Actions
      class ProcessFlow < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          false
        end

        register_instance_option :visible do
          authorized? && ProcessFlow.processable(bindings[:object])
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
            if ProcessFlow.processable(@object)
              begin
                do_flash_process_result(@object.process)
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
          'icon-play-circle'
        end


        class << self
          def processable(flow)
            flow.present?
          end
        end
      end
    end
  end
end
