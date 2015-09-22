require 'zip'

module RailsAdmin
  module Config
    module Actions
      class ImportSchema < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Schema
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            schemas = {}
            data_types_count = 0
            saved_schemas_ids = []
            if params[:_save] && data = params[:forms_import_schema_data]
              library = Setup::Library.where(id: data[:library_id]).first
              file = data[:file]
              base_uri = data[:base_uri]
              if (@object = Forms::ImportSchemaData.new(library: library, file: file, base_uri: base_uri)).valid?
                if (i = (name = file.original_filename).rindex('.')) && name.from(i) == '.zip'
                  begin
                    Zip::InputStream.open(StringIO.new(file.read)) do |zis|
                      while @object.errors.blank? && entry = zis.get_next_entry
                        if (schema = entry.get_input_stream.read).present?
                          uri = base_uri.blank? ? entry.name : "#{base_uri}/#{entry.name}"
                          schemas[entry.name] = schema = Setup::Schema.new(library: library, uri: uri, schema: schema)
                          begin
                            schema.parse_schema
                          rescue Exception => ex
                            @object.errors.add(:file, "contains invalid schema #{entry.name}: #{ex.message}")
                          end
                        end
                      end
                    end
                  rescue Exception => ex
                    @object.errors.add(:file, "Zip file format error: #{ex.message}")
                  end
                else
                  uri = base_uri.blank? ? file.original_filename : base_uri
                  schemas[uri] = Setup::Schema.new(library: library, uri: uri, schema: file.read)
                end
              end
              data_type_optimizer = Setup::DataTypeOptimizer.new_optimizer #TODO !!!
              library.set_schemas_scope(schemas.values)
              schemas.values.each(&:bind_includes)
              new_schemas_attributes = []
              schemas.each do |entry_name, schema|
                next unless @object.errors.blank?
                if schema.save_data_types && schema.validates_configuration
                  data_types_count += schema.data_types.size
                  saved_schemas_ids << schema.id
                  new_schemas_attributes << schema.attributes
                else
                  @object.errors.add(:file, "contains invalid schema #{entry_name}: #{schema.errors.full_messages.join(', ')}")
                end
              end
              data_type_optimizer.save_data_types.each { |error| @object.errors.add(:file, error) }
              begin
                Setup::Schema.collection.insert(new_schemas_attributes)
              rescue Exception => ex
                @object.errors.add(:file, "schemas could not be saved: #{ex.message}")
              end if @object.errors.blank? && new_schemas_attributes.present?
            end

            if @object && @object.errors.blank?
              flash[:success] = "#{schemas.size} schemas and #{data_types_count} data types successfully imported"
              redirect_to back_or_index
            else
              Setup::Schema.all.any_in(id: saved_schemas_ids).delete_all
              Setup::SchemaDataType.all.any_in(schema_id: saved_schemas_ids).delete_all
              @object ||= Forms::ImportSchemaData.new
              @model_config = RailsAdmin::Config.model(Forms::ImportSchemaData)
              if @object.errors.present?
                do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), @object.errors.full_messages)
              end
            end

          end
        end

        register_instance_option :link_icon do
          'icon-upload'
        end

        register_instance_option :pjax? do
          false
        end

      end
    end
  end
end