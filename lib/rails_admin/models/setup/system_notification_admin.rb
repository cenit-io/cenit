module RailsAdmin
  module Models
    module Setup
      module SystemNotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            weight 600
            visible true
            object_label_method { :label }
            label 'System Notification'

            show_in_dashboard false
            configure :created_at

            configure :type do
              pretty_value do
                "<label style='color:#{bindings[:object].color}'>#{value.to_s.capitalize}</label>".html_safe
              end
            end

            configure :message do
              pretty_value do
                "<label style='color:#{bindings[:object].color}'>#{value}</label>".html_safe
              end
            end

            configure :attachment, :storage_file

            list do
              field :created_at do
                visible do
                  if (account = Account.current)
                    request_params = bindings[:controller].params rescue {}
                    if (notification_type = request_params[:type])
                      account.meta["#{notification_type}_notifications_listed_at"] = Time.now
                    else
                      ::Setup::SystemNotification.type_enum.each do |type|
                        account.meta["#{type.to_s}_notifications_listed_at"] = Time.now
                      end
                    end
                  end
                  true
                end
              end
              field :type
              field :message
              field :attachment
              field :task
              field :updated_at
            end
          end
        end

      end
    end
  end
end
