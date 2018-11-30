module RailsAdmin
  module Models
    module Setup
      module CrossSharedCollectionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 010
            label 'Shared Collection'
            navigation_label 'Integrations'
            navigation_icon 'fa fa-puzzle-piece'
            object_label_method :versioned_name

            public_access true
            extra_associations do
              ::Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect do |association|
                association = association.dup
                association[:name] = "data_#{association.name}".to_sym
                RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)
              end
            end

            index_template_name :shared_collection_grid
            index_link_icon 'icon-th-large'

            register_instance_option(:discard_submit_buttons) do
              !(a = bindings[:action]) || a.key != :edit
            end

            asynchronous_persistence true

            instance_eval &RailsAdmin::Models::Setup::CollectionFieldsConfigAdmin::FIELDS_CONFIG
          end
        end

      end
    end
  end
end
