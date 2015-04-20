require 'zip'

module RailsAdmin
  module Config
    module Actions
      class UploadFile < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model.try(:data_type).is_a?(Setup::FileDataType)
          else
            false
          end
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            upload_file_config = RailsAdmin::Config.model(Forms::UploadFile)
            errors = []

            if model = @abstract_model.model_name.constantize rescue nil
              if (data_type = model.try(:data_type)).is_a?(Setup::FileDataType)
                if params[:_upload]
                  data = params[upload_file_config.abstract_model.param_key]
                  file = data && data[:file]
                  if (@upload_file = Forms::UploadFile.new(file: file)).valid?
                    begin
                      if data_type.validator.present? && file.original_filename.end_with?('.zip')
                        begin
                          Zip::InputStream.open(StringIO.new(file.read)) do |zis|
                            while entry = zis.get_next_entry
                              begin
                                data_type.create_from(entry.get_input_stream, filename: entry.name)
                              rescue Exception => ex
                                errors << "On entry #{entry.name}: #{ex.message.encode('UTF-8', invalid: :replace, undef: :replace)}"
                              end
                            end
                          end
                        rescue Exception => ex
                          errors << "Zip file format error: #{ex.message.encode('UTF-8', invalid: :replace, undef: :replace)}"
                        end
                      else
                        data_type.create_from(file)
                      end
                      errors = nil unless errors.present?
                    rescue Exception => ex
                      #raise ex
                      errors << ex.message.encode('UTF-8', invalid: :replace, undef: :replace)
                    end
                  end
                  # base_uri = data[:base_uri]
                  # if (@object = Forms::ImportSchemaData.new(library: library, file: file, base_uri: base_uri)).valid?
                  #   if (i = (name = file.original_filename).rindex('.')) && name.from(i) == '.zip'
                  #     schemas = []
                  #     with_missing_includes = {}
                  #     begin
                  #       Zip::InputStream.open(StringIO.new(file.read)) do |zis|
                  #         while @object.errors.blank? && entry = zis.get_next_entry
                  #           if (schema = entry.get_input_stream.read).present?
                  #             entry_uri = base_uri.blank? ? entry.name : "#{base_uri}/#{entry.name}"
                  #             schema = Setup::Schema.new(library: library, uri: entry_uri, schema: schema)
                  #             if schema.save
                  #               schemas << schema
                  #             elsif schema.include_missing?
                  #               with_missing_includes[entry.name] = schema
                  #             else
                  #               @object.errors.add(:file, "contains invalid schema in zip entry #{entry.name}: #{schema.errors.full_messages.join(', ')}")
                  #             end
                  #           end
                  #         end
                  #       end
                  #     rescue Exception => ex
                  #       @object.errors.add(:file, "Zip file format error: #{ex.message}")
                  #     end
                  #     while @object.errors.blank? && with_missing_includes.present?
                  #       with_missing_includes.each do |entry_name, schema|
                  #         next if @object.errors.present?
                  #         if schema.save
                  #           schemas << schema
                  #         elsif !schema.include_missing?
                  #           @object.errors.add(:file, "contains invalid schema in zip entry #{entry_name}: #{schema.errors.full_messages.join(', ')}")
                  #         end
                  #       end
                  #       unless with_missing_includes.size == with_missing_includes.delete_if { |_, schema| !schema.include_missing? }.size
                  #         with_missing_includes.each do |entry_name, schema|
                  #           @object.errors.add(:file, "contains invalid schema in zip entry #{entry_name}: #{schema.errors.full_messages.join(', ')}")
                  #         end
                  #       end
                  #     end
                  #     if @object.errors.blank?
                  #       dts = 0;
                  #       schemas.each { |schema| dts += schema.data_types.size }
                  #       flash[:success] = "#{schemas.length} schemas and #{dts} data types successfully imported"
                  #       redirect_to back_or_index
                  #     else
                  #       schemas.each(&:delete)
                  #     end
                  #   else
                  #     schema = Setup::Schema.new(library: library, uri: (base_uri.blank? ? file.original_filename : base_uri), schema: file.read)
                  #     if schema.save
                  #       redirect_to_on_success
                  #     else
                  #       @object.errors.add(:file, "is not a invalid schema: #{schema.errors.full_messages.join(', ')}")
                  #     end
                  #   end
                  # end
                end
              else
                errors << "Illegal action on model #{model}"
              end
            else
              errors << 'Model is not loaded'
            end

            if errors
              @upload_file ||= Forms::UploadFile.new
              @model_config = upload_file_config
              errors += @upload_file.errors.full_messages
              if errors.present?
                flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash.now[:error] += %(<br>- #{errors.join('<br>- ')}).html_safe
              end
            else
              redirect_to back_or_index
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