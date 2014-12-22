module RailsAdmin
  module Config
    module Actions
      class DataType < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model.respond_to?(:data_type_id)
          else
            false
          end
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            if data_type_id = abstract_model.model_name.constantize.data_type_id rescue nil
              redirect_to rails_admin.show_path(model_name: Setup::DataType.to_s.underscore, id: data_type_id)
            else
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :link_icon do
          'icon-wrench'
        end
      end
    end
  end
end