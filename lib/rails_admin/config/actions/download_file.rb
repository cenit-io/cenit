module RailsAdmin
  module Config
    module Actions
      class DownloadFile < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            bindings[:object].class.try(:data_type).is_a?(Setup::FileDataType) ||
              bindings[:object].is_a?(Setup::Storage)
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
            begin
              if @object.class.try(:data_type).is_a?(Setup::FileDataType)
                send_data(@object.data, filename: @object.filename, type: @object.contentType)
                errors = nil
              elsif @object.is_a?(Setup::Storage)
                redirect_to "/file/#{@object.filename}".squeeze('/')
              else
                errors << "Illegal action on model #{@object.class}"
              end
            rescue Exception => ex
              errors << ex.message
            end
            if errors.present?
              do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), errors)
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