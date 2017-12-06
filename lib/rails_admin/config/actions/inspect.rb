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
          authorized? && (obj = bindings[:object]) && !obj.sealed? &&
            (Account.current_tenant != obj || ((current_user = User.current) && !current_user.owns?(obj)))
        end

        register_instance_option :controller do
          proc do

            if (current_account = Account.current) &&
              (current_user = User.current) &&
              (current_user.super_admin? || current_user.member?(@object))
              if current_account == @object
                if current_user.owns?(@object)
                  flash[:warning] = "You are already working on #{current_account.label} account"
                else
                  current_user.account = current_user.api_account
                end
              else
                current_user.account = @object
              end
              if current_user.changed? && !current_user.save
                do_flash(:error, "Error inspecting account #{@object}", current_user.errors.full_messages)
              end
            else
              flash[:error] = 'Not authorized'
            end
            redirect_to params[:return_to] || rails_admin.show_path(model_name: Account.to_s.underscore.gsub('/', '~'), id: @object.id)
          end
        end

        register_instance_option :i18n_key do
          "#{key.to_s}." +
            (((current_account = Account.current_tenant) && bindings[:object] == current_account) ? 'out' : 'in')
        end

        register_instance_option :link_icon do
          if (current_account = Account.current)
            if bindings[:object] == current_account
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
