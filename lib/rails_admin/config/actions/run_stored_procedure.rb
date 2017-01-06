module RailsAdmin
  module Config
    module Actions
      class RunStoredProcedure < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::StoredProcedure
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:post, :get]
        end

        register_instance_option :controller do
          proc do
            mongoff_model = @object.configuration_model

            @model_config = RailsAdmin::Config.model(mongoff_model)
            @model_config.register_instance_option(:discard_submit_buttons) { true }

            if request.get?
              @form_object ||= mongoff_model.new
              render :form
            else
              begin
                params.permit! unless params.nil?
                @form_object = mongoff_model.new(params[:setup_stored_procedure_config])

                if @form_object.valid?
                  do_flash_process_result Setup::StoredProcedureExecution.process(
                    stored_procedure_id: @object.id,
                    input: @form_object.to_json,
                    skip_notification_level: true
                  )
                  redirect_to back_or_index
                elsif @form_object.errors.present?
                  do_flash(:error, 'Error!', @form_object.errors.full_messages)
                  render :form
                end
              rescue Exception => ex
                @error = ex.message
                do_flash(:error, 'Error!', @error)
                render :form
              end
            end
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