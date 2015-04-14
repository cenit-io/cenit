module RailsAdmin
  module Config
    module Actions
      class DeleteLibrary < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Library
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :delete]
        end

        register_instance_option :controller do
          proc do
            if params[:delete] # DELETE
              redirect_path = nil
              if @auditing_adapter
                schema_abstract_model = RailsAdmin::Config.model(Setup::Schema).abstract_model
                @object.schemas.each { |schema| @auditing_adapter.delete_object(schema, schema_abstract_model, _current_user) }
                @auditing_adapter.delete_object(@object, @abstract_model, _current_user)
              end
              Setup::DataType.shutdown(@object.schemas.collect(&:data_types).flatten + @object.file_data_types)
              if @object.destroy
                flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = index_path
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = back_or_index
              end
              redirect_to redirect_path
            else
              @report = Setup::DataType.shutdown(data_types = @object.schemas.collect(&:data_types).flatten + @object.file_data_types, report_only: true)
              @object.instance_variable_set(:@_schemas_to_delete, @object.schemas)
              @object.instance_variable_set(:@_to_delete, data_types)
              @object.instance_variable_set(:@_to_reload, @report[:affected].collect(&:data_type).uniq)
              render 'delete_data_definition'
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
