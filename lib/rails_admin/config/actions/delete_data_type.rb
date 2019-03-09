module RailsAdmin
  module Config
    module Actions
      class DeleteDataType < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::DataType.class_hierarchy
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            if params[:delete] # DELETE
              redirect_path = nil
              if @auditing_adapter
                @auditing_adapter.delete_object(@object, @abstract_model, _current_user)
              end
              if @object.destroy
                flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = index_path
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = back_or_index
              end
              redirect_to redirect_path
            else
              @object.instance_variable_set(:@_to_delete, @object) if @object.count.positive?
              render 'delete_data_types'
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