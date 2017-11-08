module RailsAdmin
  module Config
    module Actions
      class Records < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::DataType.class_hierarchy + [Setup::DataTypeConfig]
        end

        register_instance_option :visible do
          authorized? && (obj = bindings[:object]) && (obj.is_a?(Setup::DataTypeConfig) || obj.records_model.modelable?)
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            error_msg = nil
            data_type =
              if @object.is_a?(Setup::DataTypeConfig)
                @object.data_type
              else
                @object
              end
            begin
              if data_type
                if (model = data_type.records_model).modelable?
                  redirect_to rails_admin.index_path(model_name: RailsAdmin.config(model).abstract_model.to_param)
                else
                  error_msg = "Model #{@object.title} is not an object model"
                end
              else
                error_msg = 'Data type reference is broken'
              end
            rescue Exception => ex
              error_msg = ex.message
            end
            if error_msg
              flash[:error] = error_msg
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'icon-list'
        end
      end
    end
  end
end