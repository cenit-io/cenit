module RailsAdmin
  module Config
    module Actions
      class Configure < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Application
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            render_form = true
            mongoff_model = @object.configuration_model
            @model_config = RailsAdmin::Config.model(mongoff_model)
            model = @abstract_model.model rescue nil
            if model
              data = params.delete(@model_config.abstract_model.param_key)
              data.permit! unless data.nil? || params.delete(:_restart)
              if params.delete(:_save) && (@form_object = mongoff_model.new(data)).valid?
                @object.configuration.assign_attributes(@form_object.attributes)
                @object.save
                render_form = false
              end
            else
              flash[:error] = 'Error loading model'
            end
            if render_form
              @form_object ||= @object.configuration
              @model_config.register_instance_option(:discard_submit_buttons) { true }
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the configuration data specification', @form_object.errors.full_messages)
              end

              render :form
            else
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-sliders'
        end

        class << self

          def params_and_headers_from(object)
            params = Hash.new { |h, k| h[k] = {} }
            object.orm_model.properties_schemas.each do |property, schema|
              next unless (group = schema['group'])
              if %w(headers parameters template_parameters).include?(group)
                params[group][schema['title']] = object[property]
              end
            end
            if (content_type = object['content_type']).present? &&
              !(params.has_key?('headers') && params['headers'].has_key?('Content-Type'))
              params['headers']['Content-Type'] = content_type
            end
            params
          end
        end
      end
    end
  end
end
