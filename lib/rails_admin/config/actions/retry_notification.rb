module RailsAdmin
  module Config
    module Actions
      class RetryNotification < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [Setup::Notification]
        end

        register_instance_option :visible? do
          authorized? && bindings[:object] && bindings[:object].can_retry?
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
              redirect_to_on_success
            else
              flash[:error] = "Can not retry on notification #{@object}"
              redirect_to back_or_index
            end

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