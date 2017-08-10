module RailsAdmin
  module Models
    module Setup
      module PinAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            weight 740
            visible true
            object_label_method :to_s

            configure :model, :model
            configure :record, :record

            wizard_steps do
              steps =
                {
                  model:
                    {
                      :label => I18n.t('admin.config.pin.wizard.model.label'),
                      :description => I18n.t('admin.config.pin.wizard.model.description')
                    },
                  record:
                    {
                      label: I18n.t('admin.config.pin.wizard.record.label'),
                      description: I18n.t('admin.config.pin.wizard.record.description')
                    },
                  version:
                    {
                      label: I18n.t('admin.config.pin.wizard.version.label'),
                      description: I18n.t('admin.config.pin.wizard.version.description')
                    }
                }
            end

            current_step do
              obj = bindings[:object]
              if obj.record_model.blank?
                :model
              elsif obj.record.blank?
                :record
              else
                :version
              end
            end

            edit do
              field :record_model do
                label 'Model'
                help 'Required'
              end

              ::Setup::Pin.models.values.each do |m_data|
                field m_data[:property] do
                  inline_add false
                  inline_edit false
                  help 'Required'
                  visible { bindings[:object].record_model == m_data[:model_name] }
                  associated_collection_scope do
                    field = "#{m_data[:property]}_id".to_sym
                    excluded_ids = ::Setup::Pin.where(field.exists => true).collect(&field)
                    unless (pin = bindings[:object]).nil? || pin.new_record?
                      excluded_ids.delete(pin[field])
                    end
                    Proc.new { |scope| scope.where(:origin.ne => :default, :id.nin => excluded_ids) }
                  end
                end
              end

              field :version do
                help 'Required'
                visible { bindings[:object].ready_to_save? }
              end
            end

            show do
              field :model

              ::Setup::Pin.models.values.each do |m_data|
                field m_data[:property]
              end

              field :version
              field :updated_at
            end

            fields :model, :record, :version, :updated_at

            show_in_dashboard false
          end
        end

      end
    end
  end
end
