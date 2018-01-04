module RailsAdmin
  module Config
    module Actions
      class RetryTask < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Task.class_hierarchy
        end

        register_instance_option :visible? do
          authorized? && (obj = bindings[:object]) && obj.can_retry?
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do

            if @object.can_retry?
              @object.retry
            else
              flash[:error] = "Can not retry on notification #{@object}"
            end
            redirect_to rails_admin.show_path(model_name: @object.class.to_s.underscore.gsub('/', '~'), id: @object.id.to_s)
          end
        end

        register_instance_option :pjax? do
          false
        end

        register_instance_option :link_icon do
          'icon-repeat'
        end
      end
    end
  end
end