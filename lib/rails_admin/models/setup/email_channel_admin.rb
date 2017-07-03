module RailsAdmin
  module Models
    module Setup
      module EmailChannelAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Channels'
            weight 450
            object_label_method { :custom_title }

            fields :namespace, :name, :updated_at
          end
        end

      end
    end
  end
end
