module RailsAdmin
  module Config
    module Actions
      class Flows < RailsAdmin::Config::Actions::Base

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
          [:get]
        end

        register_instance_option :controller do
          proc do
            model = abstract_model.model rescue nil
            data_type = model.try(:data_type)
            if data_type
              dt_name = data_type.custom_title('/')
              flows_ids = Setup::Flow.all.select { |flow| flow.data_type == data_type }.collect(&:id)
              values = Setup::Flow.all.any_in(id: flows_ids)
              message = "<span><em>#{action_name.capitalize}</em> of <em>#{dt_name}</em></span>"
              filter_token = Cenit::Token.create(data: { criteria: values.selector, message: message }, token_span: 300)
              redirect_to rails_admin.index_path(model_name: Setup::Flow.to_s.underscore.gsub('/', '~'), filter_token: filter_token.token)
            else
              flash[:error] = 'Invalid action'
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-map-signs'
        end
      end
    end
  end
end
