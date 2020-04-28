module RailsAdmin
  module Config
    module Actions
      class Trust < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Cenit::ApplicationId
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            @object.trusted = !@object.trusted
            if @object.save
              flash[:success] =
                if @object.trusted?
                  'App is now trusted'
                else
                  "App is not trusted"
                end
            else
              flash[:error] = @object.errors.full_messages.to_sentence
            end
            redirect_to rails_admin.show_path(model_name: @abstract_model.to_param, id: @object.id)
          end
        end

        register_instance_option :i18n_key do
          bindings[:object].trusted? ? 'untrust' : 'trust'
        end

        register_instance_option :link_icon do
          bindings[:object].trusted? ? 'fa fa-ban' : 'fa fa-check-circle'
        end

        register_instance_option :pjax? do
          false
        end

      end
    end
  end
end