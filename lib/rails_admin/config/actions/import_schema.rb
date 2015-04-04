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

            if params[:_save] && data = params[:forms_import_schema_data]
              library = Setup::Library.where(id: data[:library_id]).first
              file = data[:file]
              base_uri = data[:base_uri]
              if (@object = Forms::ImportSchemaData.new(library: library, file: file, base_uri: base_uri)).valid?
                if (i = (name = file.original_filename).rindex('.')) && name.from(i) == '.zip'
                  schemas = []
                  with_missing_includes = {}
                  begin
                    Zip::InputStream.open(StringIO.new(file.read)) do |zis|
                      while @object.errors.blank? && entry = zis.get_next_entry
                        if (schema = entry.get_input_stream.read).present?
                          entry_uri = base_uri.blank? ? entry.name : "#{base_uri}/#{entry.name}"
                          schema = Setup::Schema.new(library: library, uri: entry_uri, schema: schema)
                          if schema.save
                            schemas << schema
                          elsif schema.include_missing?
                            with_missing_includes[entry.name] = schema
                          else
                            @object.errors.add(:file, "contains invalid schema in zip entry #{entry.name}: #{schema.errors.full_messages.join(', ')}")
                          end
                        end
                      end
                    end
                  rescue Exception => ex
                    @object.errors.add(:file, "Zip file format error: #{ex.message}")
                  end
                  while @object.errors.blank? && with_missing_includes.present?
                    with_missing_includes.each do |entry_name, schema|
                      next if @object.errors.present?
                      if schema.save
                        schemas << schema
                      elsif !schema.include_missing?
                        @object.errors.add(:file, "contains invalid schema in zip entry #{entry_name}: #{schema.errors.full_messages.join(', ')}")
                      end
                    end
                    unless with_missing_includes.size == with_missing_includes.delete_if { |_, schema| !schema.include_missing? }.size
                      with_missing_includes.each do |entry_name, schema|
                        @object.errors.add(:file, "contains invalid schema in zip entry #{entry_name}: #{schema.errors.full_messages.join(', ')}")
                      end
                    end
                  end
                  if @object.errors.blank?
                    dts = 0;
                    schemas.each { |schema| dts += schema.data_types.size }
                    flash[:success] = "#{schemas.length} schemas and #{dts} data types successfully imported"
                    redirect_to back_or_index
                  else
                    schemas.each(&:delete)
                  end
                else
                  schema = Setup::Schema.new(library: library, uri: (base_uri.blank? ? file.original_filename : base_uri), schema: file.read)
                  if schema.save
                    redirect_to_on_success
                  else
                    @object.errors.add(:file, "is not a invalid schema: #{schema.errors.full_messages.join(', ')}")
                  end
                end
              end
            end

            @object ||= Forms::ImportSchemaData.new
            @model_config = RailsAdmin::Config.model(Forms::ImportSchemaData)
            if @object.errors.present?
              flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
              flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
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