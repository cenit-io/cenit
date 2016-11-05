module RailsAdmin
  module Config
    module Actions
      class QueryDataType < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::DataType.class_hierarchy
        end

        register_instance_option :visible do
          authorized? && (obj = bindings[:object]) && obj.records_model.modelable?
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
            begin
              if (model = @object.records_model).modelable?
                redirect_to rails_admin.queries_path(model_name: model.to_s.underscore.gsub('/', '~'))
              else
                error_msg = "Model #{@object.title} is not an object model"
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
          'fa fa-filter'
        end
      end
    end
  end
end
