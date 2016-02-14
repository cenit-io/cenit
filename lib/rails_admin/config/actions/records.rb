module RailsAdmin
  module Config
    module Actions
      class Records < RailsAdmin::Config::Actions::Base

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

            if (model = @object.records_model).modelable?
              redirect_to rails_admin.index_path(model_name: model.to_s.underscore.gsub('/', '~'))
            else
              flash[:error] = "Model #{@object.title} is not an object model"
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