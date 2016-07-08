module RailsAdmin
  module Config
    module Actions
      class Run < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [Script, Setup::Algorithm]
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
            if params[:_save]
              begin
                params.permit! unless params.nil?
                @form_object = mongoff_model.new(params[:setup_algorithm_config])
                if @form_object.valid?
                  values = @form_object.to_hash.to_a
                  if params[:background].present?
                    task_class, id_key =
                        if @abstract_model.model == Setup::Algorithm
                          [Setup::AlgorithmExecution, :algorithm_id]
                        else
                          [::ScriptExecution, :script_id]
                        end
                    do_flash_process_result task_class.process(id_key => @object.id,
                                                               input: values,
                                                               skip_notification_level: true)
                  else
                    @output = @object.run(@input = values)
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
              render :form
            else
              @form_object ||= mongoff_model.new
              @model_config.register_instance_option(:discard_submit_buttons) { true }
              # @model_config.register_instance_option(:after_form_partial) { :run }
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the configuration data specification', @form_object.errors.full_messages)
              end

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