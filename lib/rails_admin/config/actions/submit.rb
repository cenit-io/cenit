module RailsAdmin
  module Config
    module Actions
      class Submit < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Webhook.class_hierarchy
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
            model = @abstract_model.model rescue nil
            data = {}
            connection_ready = false
            if model
              model_name = @action.class.name.split('::').last + 'Form'
              if !params.delete(:_restart) && (data = params.delete(model_name.underscore)).is_a?(Hash)
                data.permit!
              end

              schema =
                begin
                  @action.submission_schema(@object, data, params[:_save])
                rescue Exception => ex
                  flash[:error] = ex.message
                  @action.submission_schema(@object, data = {}, params[:_save])
                end
              mongoff_model = Mongoff::Model.for(data_type: model.data_type, schema: schema, name: model_name)

              if params.delete(:_save) && (@form_object = mongoff_model.new(data)).valid?
                msg = @action.params_and_headers_from(@form_object).merge!(
                  webhook_id: @object.id,
                  authorization_id: @form_object.attributes[:authorization_id],
                  connection_id: @form_object.attributes[:connection_id],
                  body: data[:body])
                do_flash_process_result Setup::Submission.process(msg)
                render_form = false
              end
            else
              flash[:error] = 'Error loading model'
            end

            if render_form
              @form_object ||= mongoff_model.new(data)
              if @form_object.connection
                connection_ready = true
              else
                if (connection = @object.connections.first || Setup::Connection.where(namespace: @object.namespace).first)
                  @form_object[:connection_id] = connection.id
                end
              end
              unless @form_object.authorization
                if (authorization = Setup::Authorization.where(namespace: @object.namespace).first)
                  @form_object[:authorization_id] = authorization.id
                end
              end
              @form_object.define_singleton_method(:ready_to_save?) { connection_ready && mongoff_model.schema['properties'].keys.none? { |key| key.start_with?('template_parameter') } }
              @form_object.define_singleton_method(:can_be_restarted?) { ready_to_save? }


              @model_config = RailsAdmin::Config.model(mongoff_model)
              @model_config.register_instance_option(:discard_submit_buttons) { true }
              if connection_ready
                if @form_object.connection
                  @model_config.field(:connection).partial { :selected_field }
                end
                if @form_object.authorization
                  @model_config.field(:authorization).partial { :selected_field }
                end
              end
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the submission data specification', @form_object.errors.full_messages)
              end

              render :form
            else
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'icon-play-circle'
        end

        def params_and_headers_from(object)
          params = Hash.new { |h, k| h[k] = {} }
          object.orm_model.properties_schemas.each do |property, schema|
            next unless (group = schema[:params_group]) && (key = schema[:param_key])
            group = group.to_s
            next unless %w(headers parameters template_parameters).include?(group)
            params[group][key.to_s] = object[property]
          end
          if (content_type = object['content_type']).present? &&
             !(params.has_key?('headers') && params['headers'].has_key?('Content-Type'))
            params['headers']['Content-Type'] = content_type
          end
          params
        end

        def build_params_schema(webhook, property_names, required, get_params_proc = nil)
          webhook.params_stack.inject({}) do |schema, entity|
            entity_schema = property_names.keys.inject({}) do |hash, params_group|
              h = (get_params_proc ? get_params_proc.call(entity, params_group) : (entity.try(params_group) || [])).inject({}) do |params_hash, param|
                unless (property_name = property_names[params_group][param.key])
                  property_name = property_names[params_group][param.key] = "#{params_group.to_s.singularize}_#{property_names[params_group].size + 1}"
                end
                params_hash[property_name] =
                  ph =
                    (param.metadata || {}).deep_dup.merge!(
                      'title' => param.key.to_title,
                      'description' => param.description,
                      'group' => params_group.to_s.to_title,
                      params_group: params_group,
                      param_key: param.key)
                ph['type'] ||= 'string'
                if (value = param.value)
                  ph['default'] = value
                end
                required << property_name if ph.delete('required')
                yield(params_group, param) if block_given?
                params_hash
              end
              if (metadata = entity.try(:metadata)).is_a?(Hash) &&
                 (params_metadata = metadata[params_group]).is_a?(Hash)
                params_metadata.each do |key, param_hash|
                  if (property_name = property_names[params_group][key])
                    h.merge!(property_name => param_hash)
                  end
                end
              end
              hash.merge!(h)
            end
            schema.deep_merge!(entity_schema)
          end
        end

        def submission_schema(webhook, data, skip_template_parameters = false)
          data ||= {}
          connection = Setup::Connection.where(id: data[:connection_id]).first
          authorization = Setup::Authorization.where(id: data[:authorization_id]).first
          template_parameters_data = {}
          data.each do |key, value|
            next unless key.to_s.start_with?('template_parameter')
            template_parameters_data[key] = value
          end
          required = ['connection']
          content_type_header = false
          params_properties =
            if connection
              webhook = webhook.with(connection).and(authorization)
              template_parameters_schema = build_params_schema(webhook, { template_parameters: {} }, required)
              if template_parameters_schema.any? && template_parameters_data.empty? && !skip_template_parameters
                template_parameters_schema
              else
                template_parameters = webhook.template_parameters_hash
                template_parameters_schema.each do |property, schema|
                  next unless (value = template_parameters_data[property])
                  template_parameters[schema[:param_key]] = value
                end
                get_params_proc = proc do |entity, params_group|
                  if entity.respond_to?(params_group)
                    if entity.is_a?(Setup::WithTemplateParameters)
                      conformed = entity.send("conformed_#{params_group}", template_parameters)
                      params = entity.send(params_group).collect do |param|
                        p = Setup::Parameter.new(param.attributes)
                        p.value = conformed.delete(p.key)
                        p
                      end
                      conformed.each do |key, value|
                        params << Setup::Parameter.new(key: key, value: value)
                      end
                      params
                    else
                      entity.send(params_group)
                    end
                  else
                    []
                  end
                end
                build_params_schema(webhook, { headers: {}, parameters: {} }, required, get_params_proc) do |params_group, param|
                  content_type_header ||= params_group == :headers && param.key == 'Content-Type'
                end
              end
            else
              {}
            end
          if connection && %w(get delete).exclude?(webhook.method)
            body_properties =
              {
                'body' => {
                  'type' => 'string',
                  'group' => 'body'
                }
              }
            unless content_type_header
              content_type_property =
                {
                  'type' => 'string',
                  'group' => 'body'
                }
              body_properties['content_type'] = content_type_property
              if (consumes = webhook.metadata['consumes'])
                consumes = [consumes] unless consumes.is_a?(Enumerable)
                content_type_property['default'] = consumes.first.to_s
              end
            end
            params_properties.merge!(body_properties)
          end
          {
            'type' => 'object',
            'required' => required,
            'properties' => {
              'connection' => {
                '$ref' => Setup::Connection.to_s,
                'referenced' => true
              },
              'authorization' => {
                '$ref' => Setup::Authorization.to_s,
                'referenced' => true
              }
            }.merge!(params_properties)
          }
        end
      end
    end
  end
end
