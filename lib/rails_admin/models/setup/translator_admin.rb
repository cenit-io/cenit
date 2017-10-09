module RailsAdmin
  module Models
    module Setup
      module TranslatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            label 'Transformation'
            visible false
            weight 410
            object_label_method { :custom_title }
            register_instance_option(:form_synchronized) do
              if bindings[:object].not_shared?
                [
                  :source_data_type,
                  :target_data_type,
                  :code,
                  :target_importer,
                  :source_exporter,
                  :discard_chained_records
                ]
              end
            end

            configure :namespace, :enum_edit

            configure :code, :code

            configure :source_data_type, :contextual_belongs_to do
              include_blanks_on_collection_scope true
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY

              field :type, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY

              field :source_data_type do
                shared_read_only
                inline_edit false
                inline_add false
                visible { [:Export, :Conversion].include?(bindings[:object].type) }
                help { bindings[:object].type == :Conversion ? 'Required' : 'Optional' }
              end

              field :target_data_type do
                shared_read_only
                inline_edit false
                inline_add false
                visible { [:Import, :Update, :Conversion].include?(bindings[:object].type) }
                help { bindings[:object].type == :Conversion ? 'Required' : 'Optional' }
              end

              field :discard_events do
                shared_read_only
                visible { [:Import, :Update, :Conversion].include?(bindings[:object].type) }
                help "Events won't be fired for created or updated records if checked"
              end

              field :style do
                shared_read_only
                visible { bindings[:object].type.present? }
                help 'Required'
              end

              field :bulk_source do
                shared_read_only
                visible { bindings[:object].type == :Export && bindings[:object].style.present? && bindings[:object].source_bulkable? }
              end

              field :mime_type do
                shared_read_only
                label 'MIME type'
                visible { bindings[:object].type == :Export && bindings[:object].style.present? }
              end

              field :file_extension do
                shared_read_only
                visible { bindings[:object].type == :Export && !bindings[:object].file_extension_enum.empty? }
                help { "Extensions for #{bindings[:object].mime_type}" }
              end

              field :source_handler do
                shared_read_only
                visible { (t = bindings[:object]).style.present? && (t.type == :Update || (t.type == :Conversion && t.style == 'ruby')) }
                help { 'Handle sources on code' }
              end

              field :code, :code do
                visible { bindings[:object].style.present? && bindings[:object].style != 'chain' }
                help { 'Required' }
                code_config do
                  {
                    mode: case bindings[:object].style
                          when 'html.erb'
                            'text/html'
                          when 'xslt'
                            'application/xml'
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
                  limit = (associated_collection_cache_all ? nil : 30)
                  data_type = bindings[:object].source_data_type
                  Proc.new { |scope| scope.all(type: :Conversion, source_data_type: data_type).limit(limit) }
                end
              end

              field :target_importer do
                shared_read_only
                inline_add { bindings[:object].target_importer.nil? }
                visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type && bindings[:object].source_exporter }
                help 'Required'
                associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  translator = bindings[:object]
                  source_data_type =
                    if translator.source_exporter
                      translator.source_exporter.target_data_type
                    else
                      translator.source_data_type
                    end
                  target_data_type = bindings[:object].target_data_type
                  Proc.new { |scope| scope.all(type: :Conversion, source_data_type: source_data_type, target_data_type: target_data_type).limit(limit) }
                end
              end

              field :discard_chained_records do
                shared_read_only
                visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type && bindings[:object].source_exporter }
                help "Chained records won't be saved if checked"
              end
            end

            show do
              field :namespace
              field :name
              field :type
              field :source_data_type
              field :bulk_source
              field :target_data_type
              field :discard_events
              field :style
              field :mime_type
              field :file_extension
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
              field :type
              field :style
              field :mime_type
              field :file_extension
              field :updated_at
            end

            fields :namespace, :name, :type, :style, :code, :source_data_type, :target_data_type, :updated_at
          end
        end

      end
    end
  end
end
