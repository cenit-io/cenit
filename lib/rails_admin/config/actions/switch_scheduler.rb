module RailsAdmin
  module Config
    module Actions
      class SwitchScheduler < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Scheduler
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            if @object.activated?
              @object.deactivate
            else
              @object.activate
            end
            flash[:success] = "Scheduler #{@object.custom_title} is now " + (@object.activated? ? 'activated' : 'deactivated')
            redirect_to rails_admin.show_path(model_name: @object.class.to_s.underscore.gsub('/', '~'), id: @object.id)
          end
        end

        register_instance_option :i18n_key do
          "#{key.to_s}.#{bindings[:object].activated? ? 'deactivate' : 'activate'}"
        end

        register_instance_option :link_icon do
          bindings[:object].activated? ? 'icon-off' : 'icon-play-circle'
        end

        register_instance_option :pjax? do
          false
        end

      end
    end
  end
end