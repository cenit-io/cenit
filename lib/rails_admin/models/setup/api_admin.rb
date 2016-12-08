module RailsAdmin
  module Models
    module Setup
      module ApiAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            weight 200
            label 'API'

            configure :specification, :code do
              code_config do
                {
                  mode: 'text/x-yaml'
                }
              end
            end

            fields :name, :specification
          end
        end

      end
    end
  end
end
