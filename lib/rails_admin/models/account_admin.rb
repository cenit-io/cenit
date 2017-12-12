module RailsAdmin
  module Models
    module AccountAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 810
          navigation_label 'Administration'
          label 'Tenants'
          navigation_icon 'fa fa-home'
          object_label_method { :label }

          visible { User.current.present? }

          configure :_id do
            visible { Account.current_super_admin? }
          end
          configure :key do
            pretty_value do
              (value || '<i class="icon-lock"/>').html_safe
            end
          end
          configure :token do
            pretty_value do
              (value || '<i class="icon-lock"/>').html_safe
            end
          end
          configure :notification_level
          configure :time_zone do
            label 'Time Zone'
          end

          show do
            field :name
            field :key
            field :token
            field :owner
            field :users
            field :meta
            field :notification_level
            field :time_zone
          end

          edit do
            field :name
            field :owner do
              visible { Account.current_super_admin? }
            end
            field :users do
              visible { Account.current_super_admin? }
            end
            field :key do
              visible { Account.current_super_admin? }
            end
            field :token do
              visible { Account.current_super_admin? }
            end
            field :notification_level
            field :time_zone
            field :index_max_entries do
              visible { Account.current_super_admin? }
            end
          end

          fields :_id, :name, :owner, :users, :notification_level, :time_zone

        end
      end

    end
  end
end
