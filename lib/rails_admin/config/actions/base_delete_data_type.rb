module RailsAdmin
  module Config
    module Actions
      class BaseDeleteDataType < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [Setup::JsonDataType, Setup::FileDataType]
        end

        register_instance_option :http_methods do
          [:get, :delete]
        end

        register_instance_option :controller do
          proc do

            data_types =
              if @object
                [@object]
              elsif (@bulk_ids = params[:bulk_ids] || []).present?
                Setup::DataType.any_in(id: @bulk_ids)
              else
                list_entries
              end
            if params[:delete] # DELETE
              if @auditing_adapter
                data_types.each do |data_type|
                  @auditing_adapter.delete_object(data_type, @abstract_model, _current_user)
                end
              end
              errors = []
              data_types.each do |dt|
                if !dt.destroy && errors.length < 10
                  errors = (errors + dt.errors.full_messages).flatten
                end
              end
              if errors.present?
                do_flash(:error, t('admin.actions.delete_data_type_errors'), errors)
              end
              redirect_to back_or_index
            else
              @object = Object.new
              @object.instance_variable_set(:@_to_delete, data_types) if data_types.count > 0
              render :delete_data_types
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