module RailsAdmin
  module Config
    module Actions
      class DownloadFile < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model.try(:data_type).is_a?(Setup::FileDataType)
          else
            false
          end
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do

            errors = []

            if (@object.class.try(:file_model).try(:data_type)).is_a?(Setup::FileDataType)
              begin
                send_data(@object.file.data, filename: @object.filename, type: @object.contentType)
                errors = nil
              rescue Exception => ex
                errors << ex.message
              end
            else
              errors << "Illegal action on model #{model}"
            end

            if errors
              flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
              flash.now[:error] += %(<br>- #{errors.join('<br>- ')}).html_safe
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :link_icon do
          'icon-download'
        end

        register_instance_option :pjax? do
          false
        end

      end
    end
  end
end