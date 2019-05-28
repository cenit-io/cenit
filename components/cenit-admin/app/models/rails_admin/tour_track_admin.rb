module RailsAdmin
  module Models
    module TourTrackAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 841
          navigation_label 'Administration'
          object_label_method { :to_s }
          visible { ::User.current_super_admin? }

          fields :ip, :user_email, :updated_at
        end
      end
    end
  end
end
