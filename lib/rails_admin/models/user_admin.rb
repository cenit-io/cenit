module RailsAdmin
  module Models
    module UserAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 805
          navigation_label 'Administration'
          visible { ::User.current_super_admin? }
          object_label_method { :label }

          group :accounts do
            label 'Accounts'
            active true
          end

          group :credentials do
            label 'Credentials'
            active true
          end

          group :activity do
            label 'Activity'
            active true
          end

          configure :name, :string
          configure :given_name, :string
          configure :family_name, :string
          configure :email
          configure :code_theme
          configure :roles
          configure :account do
            group :accounts
            label 'Current Account'
          end
          configure :api_account do
            group :accounts
            label 'API Account'
          end
          configure :accounts do
            group :accounts
            read_only { !::User.current_super_admin? }
          end
          configure :member_accounts do
            group :member_accounts
            read_only { !::User.current_super_admin? }
          end
          configure :password do
            group :credentials
          end
          configure :key do
            group :credentials
          end
          configure :authentication_token do
            group :credentials
          end
          configure :confirmed_at do
            group :activity
          end
          configure :sign_in_count do
            group :activity
          end
          configure :current_sign_in_at do
            group :activity
          end
          configure :last_sign_in_at do
            group :activity
          end
          configure :current_sign_in_ip do
            group :activity
          end
          configure :last_sign_in_ip do
            group :activity
          end

          edit do
            field :picture
            field :given_name
            field :family_name
            field :code_theme
            field :email do
              visible { ::User.current_super_admin? }
            end
            field :time_zone
            field :super_admin_enabled do
              visible { (user = ::User.current) && user.has_role?(:super_admin) }
            end
            field :roles do
              visible { ::User.current_super_admin? }
            end
            field :account
            field :api_account
            field :accounts do
              visible { ::User.current_super_admin? }
            end
            field :member_accounts do
              visible { ::User.current_super_admin? }
            end
            field :password do
              visible { ::User.current_super_admin? }
            end
            field :key do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
            field :authentication_token do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
            field :confirmed_at do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
            field :sign_in_count do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
            field :current_sign_in_at do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
            field :last_sign_in_at do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
            field :current_sign_in_ip do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
            field :last_sign_in_ip do
              visible { !bindings[:object].new_record? && ::User.current_super_admin? }
            end
          end

          show do
            field :picture
            field :name
            field :email
            field :time_zone
            field :code_theme do
              label 'Code Theme'
            end
            field :account
            field :api_account
            field :accounts
            field :member_accounts
            field :super_admin_enabled do
              visible { (user = ::User.current) && user.has_role?(:super_admin) }
            end
            field :roles
            field :key
            field :authentication_token
            field :sign_in_count
            field :current_sign_in_at
            field :last_sign_in_at
            field :current_sign_in_ip
            field :last_sign_in_ip
          end

          list do
            field :name
            field :given_name
            field :family_name
            field :email
            field :time_zone
            field :account
            field :sign_in_count
            field :created_at
          end

        end
      end
    end
  end
end
