module RailsAdmin
  module Config
    module Actions
      class Cancel < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          RabbitConsumer
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :delete]
        end

        register_instance_option :controller do
          proc do
            if request.get? # Ask

              respond_to do |format|
                format.html { render @action.template_name }
                format.js { render @action.template_name, layout: false }
              end

            elsif request.delete? || params[:cancel] # Cancel

              redirect_path = nil
              if @object.try(:cancel)
                flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.cancel.done'))
                redirect_path = index_path
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.cancel.done'))
                redirect_path = back_or_index
              end

              redirect_to redirect_path

            end
          end
        end

        register_instance_option :link_icon do
          'icon-off'
        end
      end
    end
  end
end
