module RailsAdmin
  module Models
    module Setup
      module CollectionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 000
            navigation_label 'Collections'
            register_instance_option :label_navigation do
              'My Collections'
            end

            instance_eval &RailsAdmin::Models::Setup::CollectionFieldsConfigAdmin::FIELDS_CONFIG
          end
        end

      end
    end
  end
end
