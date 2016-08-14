module RailsAdmin
  module Config
    module Actions
      class BaseDeleteDataType < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::DataType.class_hierarchy
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
                Setup::DataType.all
              end
            if params[:delete] # DELETE
              data_types.each { |data_type| @auditing_adapter.delete_object(data_type, @abstract_model, _current_user) } if @auditing_adapter
              data_types.each(&:destroy)
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