require 'zip'

module RailsAdmin
  module Config
    module Actions
      class UploadFile < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model rescue nil
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
                      if data_type.validators.present? && file.original_filename.end_with?('.zip')
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
                      elsif (file = data_type.create_from(file)).errors.present?
                        errors += file.errors.full_messages
                      end
                      errors = nil unless errors.present?
                    rescue Exception => ex
                      #raise ex
                      errors << ex.message
                    end
                  end
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
                errors = errors.collect { |error| error.encode('UTF-8', invalid: :replace, undef: :replace) }
                do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), errors)
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