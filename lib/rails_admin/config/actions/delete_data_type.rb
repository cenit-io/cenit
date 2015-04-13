module RailsAdmin
  module Config
    module Actions
      class DeleteDataType < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Model
        end

        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(Setup::FileDataType)
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            if @object.is_a?(Setup::FileDataType)
              if params[:delete] # DELETE
                redirect_path = nil
                if @auditing_adapter
                  @auditing_adapter.delete_object(@object, @abstract_model, _current_user)
                end
                Setup::DataType.shutdown(@object)
                if @object.destroy
                  flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.delete.done'))
                  redirect_path = index_path
                else
                  flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.delete.done'))
                  redirect_path = back_or_index
                end
                redirect_to redirect_path
              else
                @report = Setup::DataType.shutdown(@object, report_only: true)
                @object.instance_variable_set(:@_to_delete, @object) if @object.count > 0
                to_shutdown = @report[:destroyed].collect(&:data_type).uniq
                to_shutdown.delete(@object)
                @object.instance_variable_set(:@_to_shutdown, to_shutdown)
                @object.instance_variable_set(:@_to_reload, @report[:affected].collect(&:data_type).uniq)
                render 'delete_data_definition'
              end
            else
              flash[:error] = 'Not allowed'
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'icon-remove'
        end
      end
    end
  end
end