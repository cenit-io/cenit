module RailsAdmin
  module Config
    module Actions
      class Regist < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Application
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :patch]
        end

        register_instance_option :controller do
          proc do
            render_form = true
            app_id = @object.application_id
            app_id_config = RailsAdmin::Config.model(Cenit::ApplicationId)
            if (registration_data = params[app_id_config.abstract_model.param_key]) && registration_data.permit! &&
              (app_id.regist_with(registration_data)).valid? && app_id.save
              render_form = false
            end
            if render_form
              @form_object = app_id
              @model_config = app_id_config
              if @form_object.errors.present?
                do_flash_now(:error, 'Invalid data', @form_object.errors.full_messages)
              end
              @object.instance_variable_set(:@registering, true)
              @form_object.instance_variable_set(:@registering, true)
              render :form
            else
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-registered'
        end
      end
    end
  end
end