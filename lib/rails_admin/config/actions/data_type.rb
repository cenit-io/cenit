module RailsAdmin
  module Config
    module Actions
      class DataType < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            begin
              bindings[:abstract_model].model.data_type.present?
            rescue
              false
            end
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
            model = abstract_model.model rescue nil
            if model && (data_type = model.data_type)
              redirect_to rails_admin.show_path(model_name: data_type.class.to_s.underscore.gsub('/', '~'), id: data_type.id.to_s)
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