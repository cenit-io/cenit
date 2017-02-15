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

            configure :resource do
              read_only true
              RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
            end

            configure :description do
              RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
            end

            configure :method do
              RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
            end

            configure :metadata, :json_value

            fields :method, :description, :parameters, :headers, :resource, :metadata
          end
        end

      end
    end
  end
end
