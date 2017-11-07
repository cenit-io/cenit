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
            if model
              connection =
                if (data = params.delete((model_name = @action.class.name.split('::').last + 'Form').underscore))
                  data.permit!
                  connection = Setup::Connection.where(id: data[:connection_id]).first
                else
                  selecting_connection = true
                  @object.connections.first || Setup::Connection.where(namespace: @object.namespace).first
                end unless params.delete(:_restart)
              mongoff_model = Mongoff::Model.for(data_type: model.data_type,
                                                 schema: Submit.params_schema(@object, selecting_connection ? nil : connection),
                                                 name: model_name)
              if params.delete(:_save) && (@form_object = mongoff_model.new(data)).valid?
                msg = Submit.params_and_headers_from(@form_object).merge!(webhook_id: @object.id,
                                                                          authorization_id: @form_object.attributes[:authorization_id],
                                                                          connection_id: connection.id,
                                                                          body: data[:body])
                do_flash_process_result Setup::Submission.process(msg)
                render_form = false
              end
            else
              flash[:error] = 'Error loading model'
            end
            if render_form
              @form_object ||= mongoff_model.new(authorization: Setup::Authorization.where(namespace: @object.namespace).first,
                                                 connection: connection)
              @form_object.define_singleton_method(:ready_to_save?) { !selecting_connection && connection.present? }
              @form_object.define_singleton_method(:can_be_restarted?) { ready_to_save? }


              @model_config = RailsAdmin::Config.model(mongoff_model)
              @model_config.register_instance_option(:discard_submit_buttons) { true }
              if connection
                @model_config.configure(:connection).associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  Proc.new { |scope| scope.where(id: connection.id).limit(limit) }
                end
              end unless selecting_connection
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

          def params_schema(webhook, connection)
            required = ['connection']
            content_type_header = false
            params_properties =
              if connection
                c = 0
                property_names =
                  {
                    headers: {},
                    parameters: {},
                    template_parameters: {}
                  }
                webhook.with(connection).params_stack.inject({}) do |hash, entity|
                  entity_hash = property_names.keys.inject({}) do |hash, params|
                    h = entity.send(params).inject({}) do |params_hash, param|
                      unless (property_name = property_names[params][param.key])
                        property_name = property_names[params][param.key] = "property_#{c += 1}"
                      end
                      params_hash[property_name] =
                        ph =
                          (param.metadata || {}).deep_dup.merge!('title' => param.key,
                                                                 'description' => param.description,
                                                                 'group' => params.to_s)
                      ph['type'] ||= 'string'
                      if (value = param.value)
                        ph['default'] = value
                      end
                      required << property_name if ph.delete('required')
                      content_type_header ||= params == :headers && param.key == 'Content-Type'
                      params_hash
                    end
                    if (metadata = entity.try(:metadata)).is_a?(Hash) &&
                      (params_metadata = metadata[params]).is_a?(Hash)
                      params_metadata.each do |key, param_hash|
                        if (property_name = property_names[params][key])
                          h.merge!(property_name => param_hash)
                        end
                      end
                    end
                    hash.merge! h
                  end
                  hash.deep_merge! entity_hash
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
end