module RailsAdmin
  module Models
    module Setup
      module OperationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            weight 217
            object_label_method { :label }
            visible { Account.current_super_admin? }

            configure :resource do
              read_only true
              RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
            end

            configure :description do
              RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
            end

            configure :method do
              RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
            end

            configure :metadata, :json_value

            fields :method, :description, :parameters, :headers, :resource, :metadata
          end
        end

      end
    end
  end
end
