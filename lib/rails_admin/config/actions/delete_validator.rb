module RailsAdmin
  module Config
    module Actions
      class DeleteValidator < RailsAdmin::Config::Actions::Base #TODO Delete these action

        register_instance_option :only do
          [Setup::Schema, Setup::EdiValidator]
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
                @object.data_types.each do |data_type|
                  @auditing_adapter.delete_object(data_type, RailsAdmin::Config.model(data_type.model).abstract_model, _current_user) if data_type.loaded?
                end if @object.is_a?(Setup::Schema)
                @auditing_adapter.delete_object(@object, @abstract_model, _current_user)
              end
              if @object.destroy
                flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.delete.done'))
                report = @object.instance_variable_get(:@shutdown_report)
                if (report && report[:errors]).present?
                  flash[:error] = ''.html_safe
                  report[:errors].each do |data_type, errors|
                    do_flash(:error, "<strong>Model #{data_type.title} could not be loaded</strong>", errors.full_messages, reset: false)
                  end
                end
                redirect_path = index_path
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = back_or_index
              end
              redirect_to redirect_path
            else
              if @object.is_a?(Setup::Schema)
                @report = Setup::DataType.shutdown(@object.data_types.activated, report_only: true)
                @object.instance_variable_set(:@_to_delete, @object.data_types)
                @object.instance_variable_set(:@_to_shutdown, @report[:destroyed].collect(&:data_type).uniq.select { |data_type| data_type.schema != @object })
                @object.instance_variable_set(:@_to_reload, @report[:affected].collect(&:data_type).uniq)
              end
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
