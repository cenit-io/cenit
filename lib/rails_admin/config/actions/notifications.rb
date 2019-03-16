module RailsAdmin
  module Config
    module Actions
      class Notifications < RailsAdmin::Config::Actions::Base

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

        register_instance_option :link_icon do
          'fa fa-envelope'
        end

        register_instance_option :controller do
          proc do
            model = abstract_model.model
            data_type = model.try(:data_type)
            if data_type
              redirect_to rails_admin.index_path(
                model_name: Setup::Notification.name.underscore.gsub('/', '~'),
                context_model: Setup::DataType.name,
                context_id: data_type.id
              )
            else
              flash[:error] = 'Invalid action'
              redirect_to back_or_index
            end
          end
        end
      end
    end
  end
end
