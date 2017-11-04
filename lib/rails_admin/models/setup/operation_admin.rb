module RailsAdmin
  module Models
    module Setup
      module OperationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            navigation_icon 'fa fa-cog'
            weight 217
            object_label_method { :custom_title }

            search_associations do
              :resource
            end

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

            fields :resource, :method, :description, :parameters

            filter_query_fields :none
          end
        end

      end
    end
  end
end
