module RailsAdmin
  module Config
    module Actions
      class Filters < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            model = abstract_model.model rescue nil
            dt_name = ''
            data_type = if (dt = model.data_type).is_a?(Setup::BuildInDataType)
                          dt_name = dt.name
                          namespace, name = dt.name.split('::')
                          Setup::CenitDataType.find_or_create_by(namespace: namespace, name: name)
                        else
                          dt_name = dt.custom_title('/')
                          model.data_type
                        end
            values = Setup::Filter.where(data_type_id: data_type)
            message = "<span><em>#{action_name.capitalize}</em> of <em>#{dt_name}</em></span>"
            filter_token = Cenit::Token.create(data: { criteria: values.selector, message: message},token_span: 300)
            redirect_to rails_admin.index_path(model_name: Setup::Filter.to_s.underscore.gsub('/', '~'), filter_token: filter_token.token)
          end
        end

        register_instance_option :link_icon do
          'fa fa-filter'
        end
      end
    end
  end
end
