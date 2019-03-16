module RailsAdmin
  module Config
    module Actions
      class Run < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Algorithm
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

            done = false
            partials = [:background_run_option]

            if params[:_save]
              begin
                params.permit! unless params.nil?
                @form_object = mongoff_model.new(params[:setup_algorithm_config])
                if @form_object.valid?
                  values = @form_object.to_hash.values.to_a
                  if params[:background].present?
                    do_flash_process_result Setup::AlgorithmExecution.process(algorithm_id: @object.id,
                                                                              input: values,
                                                                              skip_notification_level: true)
                    redirect_to back_or_index
                    done = true
                  else
                    @output = @object.run(@input = values)
                    partials.unshift :algorithm_output
                  end
                else
                  if @form_object.errors.present?
                    do_flash(:error, 'Error!', @form_object.errors.full_messages)
                  end
                end
              rescue Exception => ex
                @error = ex.message
                do_flash(:error, 'Error!', @error)
              end
            else
              @form_object ||= mongoff_model.new
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the configuration data specification', @form_object.errors.full_messages)
              end
            end
            unless done
              @model_config.register_instance_option(:after_form_partials) { partials }
              render :form
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
