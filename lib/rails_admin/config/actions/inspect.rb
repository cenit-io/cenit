module RailsAdmin
  module Config
    module Actions
      class Inspect < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Account
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :visible? do
          authorized? &&
            (current_account = Account.current) &&
            (current_user = User.current) &&
            current_user.super_admin?
        end

        register_instance_option :controller do
          proc do
            if (current_account = Account.current) && (current_user = User.current) && current_user.super_admin?
              current_account.tenant_account = (current_account.tenant_account == @object) ? nil : @object
              current_account.save
            else
              flash[:error] = 'Not authorized'
            end
            redirect_to params[:return_to] || rails_admin.show_path(model_name: Account.to_s.underscore.gsub('/', '~'), id: @object.id)
          end
        end

        register_instance_option :i18n_key do
          "#{key.to_s}." +
            (((current_account = Account.current) && bindings[:object] == current_account.tenant_account) ? 'out' : 'in')
        end

        register_instance_option :link_icon do
          if (current_account = Account.current)
            if bindings[:object] == current_account.tenant_account
              'icon-eye-close'
            else
              'icon-eye-open'
            end
          else
            'icon-ban-circle'
          end
        end

        register_instance_option :pjax? do
          false
        end

      end

    end
  end
end