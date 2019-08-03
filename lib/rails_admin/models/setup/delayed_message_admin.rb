module RailsAdmin
  module Models
    module Setup
      module DelayedMessageAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 880
            navigation_label 'Administration'
            visible { ::User.current_super_admin? }

            configure :live_publish_at, :datetime

            edit do
              field :message
            end

            fields :updated_at, :message, :publish_at, :live_publish_at, :unscheduled, :scheduler, :tenant
          end
        end
      end
    end
  end
end
