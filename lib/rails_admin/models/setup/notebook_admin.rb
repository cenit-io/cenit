module RailsAdmin
  module Models
    module Setup
      module NotebookAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            weight 400
            object_label_method { :path }

            list do
              field :module
              field :name
              field :shared
              field :writable
            end

            fields :module, :name, :shared, :content
          end
        end

      end
    end
  end
end
