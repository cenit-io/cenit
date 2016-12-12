module RailsAdmin
  module Models
    module Setup
      module ApiSpecAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            weight 200
            label 'API Spec'

            configure :specification, :code do
              code_config do
                {
                  mode: 'text/x-yaml',
                  readOnly: 'nocursor'
                }
              end
            end

            edit do
              configure :specification, :code do
                code_config do
                  {
                    mode: 'text/x-yaml',
                  }
                end
              end
              fields :title, :specification
            end

            fields :title, :specification
          end
        end

      end
    end
  end
end
