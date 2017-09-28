module RailsAdmin
  module Models
    module Setup
      module ConverterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 413
            configure :code, :code
            navigation_label 'Transforms'
            navigation_icon 'fa fa-files-o'

            wizard_steps do
              steps =
                {
                  start:
                    {
                      :label => I18n.t('admin.config.converter.wizard.start.label'),
                      :description => I18n.t('admin.config.converter.wizard.start.description')
                    }
                }
              if bindings[:object].style == 'chain'
                steps[:select_exporter] =
                  {
                    label: I18n.t('admin.config.converter.wizard.select_exporter.label'),
                    description: I18n.t('admin.config.converter.wizard.select_exporter.description')
                  }
              end
              steps[:end] =
                {
                  label: I18n.t('admin.config.converter.wizard.end.label'),
                  description: I18n.t('admin.config.converter.wizard.end.description')
                }
              steps
            end

            current_step do
              style = (obj = bindings[:object]).style
              if obj.source_data_type.blank? || obj.target_data_type.blank? || obj.style.blank?
                :start
              elsif style == 'chain' && obj.source_exporter.blank?
                :select_exporter
              else
                :end
              end
            end

            configure :namespace, :enum_edit

            extra_associations do
              association = Mongoff::Association.new(abstract_model.model, :mapping, :embeds_one)
              [RailsAdmin::MongoffAssociation.new(association, abstract_model.model)]
            end

            configure :mapping, :has_one_association

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

              field :style do
                shared_read_only
                visible { bindings[:object].type.present? }
                help 'Required'
              end

              field :source_handler do
                shared_read_only
                visible { (t = bindings[:object]).style.present? && (t.style == 'ruby') }
                help { 'Handle sources on code' }
              end

              field :code, :code do
                visible { bindings[:object].style.present? && %w(chain mapping).exclude?(bindings[:object].style) }
                help { 'Required' }
                code_config do
                  {
                    mode: case bindings[:object].style
                          when 'html.erb'
                            'text/html'
                          when 'xslt'
                            'application/xml'
                          when 'liquid'
                            'text/plain'
                          else
                            'text/x-ruby'
                          end
                  }
                end
              end

              field :source_exporter do
                shared_read_only
                inline_add { bindings[:object].source_exporter.nil? }
                visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type }
                help 'Required'
                associated_collection_scope do
                  data_type = bindings[:object].source_data_type
                  Proc.new { |scope|
                    scope.all(type: :Conversion, source_data_type: data_type)
                  }
                end
              end

              field :target_importer do
                shared_read_only
                inline_add { bindings[:object].target_importer.nil? }
                visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type && bindings[:object].source_exporter }
                help 'Required'
                associated_collection_scope do
                  translator = bindings[:object]
                  source_data_type =
                    if translator.source_exporter
                      translator.source_exporter.target_data_type
                    else
                      translator.source_data_type
                    end
                  target_data_type = bindings[:object].target_data_type
                  Proc.new { |scope|
                    scope = scope.all(type: :Conversion,
                                      source_data_type: source_data_type,
                                      target_data_type: target_data_type)
                  }
                end
              end

              field :discard_chained_records do
                shared_read_only
                visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type && bindings[:object].source_exporter }
                help "Chained records won't be saved if checked"
              end

              field :mapping do
                visible { bindings[:object].style.present? && bindings[:object].style == 'mapping' }
              end
            end

            show do
              field :namespace
              field :name
              field :source_data_type
              field :target_data_type
              field :discard_events
              field :style
              field :source_handler
              field :code
              field :source_exporter
              field :target_importer
              field :discard_chained_records

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
              field :style
              field :updated_at
            end
          end
        end

      end
    end
  end
end
