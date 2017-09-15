module RailsAdmin
  module Models
    module Setup
      module ConnectionConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            label 'Connection Config'
            visible true
            weight 730

            configure :connection do
              read_only true
            end

            configure :number do
              label 'Key'
            end

            configure :authentication_token do
              label 'Token'
            end

            fields :connection, :number, :authentication_token

            show_in_dashboard false
          end
        end

      end
    end
  end
end
