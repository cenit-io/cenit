module RailsAdmin
  module Models
    module Setup
      module NotebookAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            navigation_icon 'fa fa-list'
            weight 400
            object_label_method { :path }
            public_access true
          end
        end

      end
    end
  end
end
