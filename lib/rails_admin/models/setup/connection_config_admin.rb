module RailsAdmin
  module Models
    module Setup
      module ConnectionConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            label 'Connection Config'
            navigation_icon 'fa fa-wrench'
            visible true
            weight 730

            configure :connection do
              read_only { !bindings[:object].new_record? }
              contextual_association_scope do
                taken_ids = abstract_model.all.collect(&:connection_id)
                proc { |scope| scope.and(:id.nin => taken_ids) }
              end
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
