module RailsAdmin
  module Models
    module Setup
      module TagAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :name }
            fields :namespace, :name
          end
        end
      end
    end
  end
end
