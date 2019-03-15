module RailsAdmin
  module Models
    module Setup
      module CrossCollectionAuthorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :label }
            fields :name, :email
          end
        end
      end
    end
  end
end
