module RailsAdmin
  module Models
    module Setup
      module ConnectionConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            label 'Connection Config'
            weight 730
            configure :connection do
              read_only true
            end
            configure :number do
              label 'Key'
            end
            fields :connection, :number, :token

            show_in_dashboard false
          end
        end

      end
    end
  end
end
