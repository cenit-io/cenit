module RailsAdmin
  module Config
    module Actions
      class DataType < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            (data_type = model.try(:data_type)).present? && !data_type.is_a?(Setup::BuildInDataType)
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

            if data_type = abstract_model.model_name.constantize.try(:data_type)
              redirect_to rails_admin.show_path(model_name: Setup::Model.to_s.underscore.gsub('/', '~'), id: data_type.id.to_s)
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