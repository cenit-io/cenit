module RailsAdmin
  module Config
    module Actions
      class Schedule < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Task.class_hierarchy
        end

        register_instance_option :visible? do
          authorized? && bindings[:object] && bindings[:object].can_schedule?
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            Forms::SchedulerSelector.collection.drop
            if @object.can_schedule?
              done = false
              form_config = RailsAdmin::Config.model(Forms::SchedulerSelector)
              if (selector_params = params[form_config.abstract_model.param_key])
                selector_params.permit!
                if (@form_object = Forms::SchedulerSelector.new(selector_params)).valid?
                  @object.schedule(@form_object.scheduler)
                  done = @object.save
                end
              end
              if done
                redirect_to_on_success
              else
                @model_config = form_config
                @form_object ||= Forms::SchedulerSelector.new(scheduler: @object.scheduler)
                @form_object.target_task = @object
                if @object.errors.present?
                  do_flash(:error, "Error scheduling #{@object}", @object.errors.full_messages)
                end
                @form_object.save(validate: false)
                render :form
              end
            else
              flash[:error] = "Can not schedule #{@object}"
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :link_icon do
          'icon-time'
        end
      end
    end
  end
end