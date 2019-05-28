module RailsAdmin
  module Models
    module Setup
      module CollectionDataAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :label }
          end
        end
      end
    end
  end
end
