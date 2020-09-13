module RailsAdmin
  module Config
    module Actions
      class Attachment < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          false
        end

        register_instance_option :only do
          [Setup::SystemNotification, Setup::Execution]
        end

        register_instance_option :route_fragment do
          "#{custom_key}/*filename(.:format)"
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
              # filename = params[:filename] + (params[:format] ? ".#{params[:format]}" : '')
              if (attachment = @object.attachment) && (file = attachment.file)
                send_data(file.read, filename: file.filename, type: file.content_type)
              else
                errors << "Attachment not found"
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