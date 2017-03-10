module RailsAdmin
  module Models
    module Setup
      module RepresentationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            weight 218
            object_label_method { :custom_title }
            visible false

            edit do
              field(:namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:description, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:metadata, :json_value, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
            end

            show do
              field :namespace
              field :name
              field :metadata, :json_value

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            fields :namespace, :name, :description, :updated_at
          end
        end

      end
    end
  end
end
