module RailsAdmin
  module Config
    module Actions
      class ForeignNotifications < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model rescue nil
            model.try(:data_type).present?
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
            model = abstract_model.model rescue nil
            data_type = model.try(:data_type)
            if data_type
              dt_name = data_type.custom_title('/')
              values = Setup::ForeignNotification.where(data_type_id: data_type)
              message = "<span><em>#{action_name.capitalize}</em> of <em>#{dt_name}</em></span>"
              filter_token = Cenit::Token.create(
                data: { criteria: values.selector, message: message, data_type_id: data_type.id },
                token_span: 300
              )
              redirect_to rails_admin.index_path(
                model_name: Setup::ForeignNotification.name.underscore.gsub('/', '~'),
                filter_token: filter_token.token
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
