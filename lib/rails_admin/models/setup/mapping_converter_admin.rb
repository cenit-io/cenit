module RailsAdmin
  module Models
    module Setup
      module MappingConverterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 413
            configure :code, :code
            navigation_label 'Transforms'
            label 'Mapping Converter'
            weight 410

            wizard_steps do
              {
                start:
                  {
                    label: I18n.t('admin.config.mapping_converter.wizard.start.label'),
                    description: I18n.t('admin.config.mapping_converter.wizard.start.description')
                  },
                end:
                  {
                    label: I18n.t('admin.config.converter.wizard.end.label'),
                    description: I18n.t('admin.config.converter.wizard.end.description')
                  }
              }
            end

            current_step do
              if bindings[:object].source_data_type && bindings[:object].target_data_type
                :end
              else
                :start
              end
            end

            configure :namespace, :enum_edit

            extra_associations do
              association = Mongoff::Association.new(abstract_model.model, :mapping, :embeds_one)
              [RailsAdmin::MongoffAssociation.new(association, abstract_model.model)]
            end

            configure :mapping, :has_one_association do
              nested_form_safe true
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY

              field :source_data_type do
                shared_read_only
                inline_edit false
                inline_add false
                help 'Required'
              end

              field :target_data_type do
                shared_read_only
                inline_edit false
                inline_add false
                help 'Required'
              end

              field :discard_events do
                shared_read_only
                help "Events won't be fired for created or updated records if checked"
              end

              field :mapping do
                shared_read_only
                visible { bindings[:object].target_data_type && bindings[:object].source_data_type }
              end
            end

            show do
              field :namespace
              field :name
              field :source_data_type
              field :target_data_type
              field :discard_events
              field :mapping

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            list do
              field :namespace
              field :name
              field :source_data_type
              field :target_data_type
              field :updated_at
            end

            filter_query_fields :namespace, :name
          end
        end

      end
    end
  end
end
