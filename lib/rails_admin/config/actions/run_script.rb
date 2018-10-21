module RailsAdmin
  module Config
    module Actions
      class RunScript < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Script
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:post, :get]
        end

        register_instance_option :controller do
          proc do

            if params[:_run]
              begin
                if params[:background].present?
                  do_flash_process_result ::ScriptExecution.process(script_id: @object.id,
                                                                    input: params.delete(:input),
                                                                    skip_notification_level: true)
                else
                  @output = @object.run(@input = params.delete(:input))
                end
              rescue Exception => ex
                Setup::SystemReport.create_from(ex)
                @error = ex.message
              end
            end
            render :run
          end
        end

        register_instance_option :link_icon do
          'icon-play'
        end

        register_instance_option :pjax do
          false
        end
      end
    end
  end
end