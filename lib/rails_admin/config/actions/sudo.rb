module RailsAdmin
  module Config
    module Actions
      class Sudo < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          ::User
        end

        register_instance_option :visible do
          authorized? && (obj = bindings[:object]).is_a?(::User) && obj.has_role?(:super_admin)
        end

        register_instance_option :pjax? do
          false
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            @object.update(super_admin_enabled: !@object.super_admin_enabled)
            redirect_to rails_admin.show_path(model_name: @abstract_model.to_param, id: @object.id)
          end
        end

        register_instance_option :i18n_key do
          k = key.to_s
          if (user = User.current) && user.super_admin_enabled
            k = "#{k}.disable"
          end
          k
        end

        register_instance_option :link_icon do
          'fa fa-user-secret'
        end

      end
    end
  end
end