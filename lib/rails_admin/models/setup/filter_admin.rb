module RailsAdmin
  module Models
    module Setup
      module FilterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            weight 435
            label 'Filter'
            object_label_method { :custom_title }

            wizard_steps do
              steps =
                {
                  start:
                    {
                      :label => I18n.t('admin.config.filter.wizard.start.label'),
                      :description => I18n.t('admin.config.filter.wizard.start.description')
                    },
                  end:
                    {
                      label: I18n.t('admin.config.filter.wizard.end.label'),
                      description: I18n.t('admin.config.filter.wizard.end.description')
                    }
                }
            end

            current_step do
              obj = bindings[:object]
              if obj.data_type.blank?
                :start
              else
                :end
              end
            end

            configure :namespace, :enum_edit

            configure :segment do
              pretty_value do
                (bindings[:view].render partial: 'link_to_segment', locals:
                  {
                    name: bindings[:object].custom_title,
                    model_name: bindings[:object].data_type.records_model.to_s.underscore.gsub('/', '~'),
                    filter: bindings[:object].segment
                  }).html_safe
              end
            end

            edit do
              field :namespace
              field :name
              field :data_type do
                inline_add false
                inline_edit false
                associated_collection_scope do
                  data_type = bindings[:object].data_type
                  Proc.new { |scope|
                    if data_type
                      scope.where(id: data_type.id)
                    else
                      scope
                    end
                  }
                end
                help 'Required'
              end
              field :triggers do
                visible do
                  bindings[:controller].instance_variable_set(:@_data_type, data_type = bindings[:object].data_type)
                  bindings[:controller].instance_variable_set(:@_update_field, 'data_type_id')
                  data_type.present?
                end
                partial 'form_triggers'
                help false
              end
            end

            show do
              field :namespace
              field :name
              field :data_type
              field :triggers
              field :segment
              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            fields :namespace, :name, :data_type, :segment, :triggers, :updated_at
          end
        end

      end
    end
  end
end
