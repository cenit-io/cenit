require 'zip'

module RailsAdmin
  module Config
    module Actions
      class ImportSchema < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Library
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            library = @object

            if params[:_save]
              if (data = params[:import_schema_data]) && (file = data[:file])
                base_uri = data[:base_uri] || file.original_filename
                if (i = (name = file.original_filename).rindex('.')) && name.from(i) == '.zip'
                  schemas = []
                  is_ok = true
                  Zip::InputStream.open(StringIO.new(file.read)) do |zis|
                    while is_ok && entry = zis.get_next_entry
                      unless (schema = entry.get_input_stream.read).blank?
                        entry_uri = base_uri.blank? ? entry.name : "#{base_uri}/#{entry.name}"
                        schema = Setup::Schema.new(library: library, uri: entry_uri, schema: schema)
                        if schema.save
                          schemas << schema
                        else
                          flash[:error] = "Error creating schema from zip entry #{entry.name}"
                          flash[:error] += "<br>- #{schema.errors.full_messages.join('<br>- ')}".html_safe
                          is_ok = false
                        end
                      end
                    end
                  end
                  if is_ok
                    dts = 0;
                    schemas.each { |schema| dts += schema.data_types.size }
                    flash[:success] = "#{schemas.length} schemas and #{dts} data types successfully imported"
                  else
                    schemas.each { |schema| schema.delete }
                  end
                  redirect_to back_or_index
                else
                  schema = Setup::Schema.new(library: library, uri: base_uri, schema: file.read)
                  if schema.save
                    redirect_to_on_success
                  else
                    @object = schema
                    @model_config = RailsAdmin::Config.model(Setup::Schema)
                    params[:action] = :create
                    handle_save_error
                  end
                end
              end
            else
              @object = ImportSchemaData.new
              @model_config = RailsAdmin::Config.model(ImportSchemaData)
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