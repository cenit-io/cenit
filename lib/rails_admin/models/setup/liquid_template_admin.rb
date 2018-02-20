module RailsAdmin
  module Models
    module Setup
      module LiquidTemplateAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Liquid Template'
            weight 410
            object_label_method { :custom_title }

            visible { User.current_super_admin? && group_visible }

            configure :code, :code do
              code_config do
                {
                  mode: bindings[:object].mime_type || 'text/plain'
                }
              end
            end

            wizard_steps do
              {
                start:
                  {
                    label: I18n.t('admin.config.tempalte.wizard.start.label'),
                    description: I18n.t('admin.config.template.wizard.start.description')
                  },
                end:
                  {
                    label: I18n.t('admin.config.template.wizard.end.label'),
                    description: I18n.t('admin.config.template.wizard.end.description')
                  }
              }
            end

            current_step do
              if bindings[:object].ready_to_save?
                :end
              else
                :start
              end
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY


              field :source_data_type do
                shared_read_only
                inline_edit false
                inline_add false
              end
              field :mime_type do
                shared_read_only
                label 'MIME type'
              end
              field :file_extension do
                shared_read_only
                visible { !bindings[:object].file_extension_enum.empty? }
                help { "Extensions for #{bindings[:object].mime_type}" }
              end
              field :code, :code do
                visible { bindings[:object].ready_to_save? }
                help { 'Required' }
              end
            end

            fields :namespace, :name, :source_data_type, :mime_type, :file_extension, :code, :updated_at
          end
        end

      end
    end
  end
end
