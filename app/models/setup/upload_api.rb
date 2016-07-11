module Setup
  class UploadApi < Setup::Task
    include Setup::DataUploader

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all

    protected

    def run(msg)
      output = 'yaml'
      url = 'https://apitransformer.com/api/transform?output=%1s' %[output]
      msg = {}
      headers = {}
      headers['Content-Type'] = "text/plain"
      msg = { headers: headers }
      msg[:body] = data.read
      msg[:timeout] = 240
      http_response = HTTMultiParty.send('post', url, msg)
      spec = http_response.body

      if http_response.code == 412
        Setup::Notification.create_with(message: http_response.body, type: :error)
      else
        create_collection(spec)
      end

    end

    def create_collection(swagger_spec)
      spec = Psych.load(swagger_spec)
      [
          definitions = spec['definitions'] || {},
          parameters = spec['parameters'] || {},
          paths = spec['paths'] || {}
      ].each do |schema_container|
        schema_container.each_deep_pair do |hash, key, value|
          if key == '$ref' && !(value.is_a?Hash)
            if value.start_with?(prefix = '#/definitions/') || value.start_with?(prefix = '#/parameters/')
              hash[key] = value.from(prefix.length)
            elsif value.start_with?('#/')
              hash[key] = value.from(2)
            else
              flash[:error] =  "Ref #{value} is not valid"
            end
          end
        end if schema_container
      end

      parameters.each { |param| flash[:error] = "Parameter name conflict with definition: #{param}" if definitions.has_key?(param) }

      #Checking definitions
      check_definitions(definitions)

      namespace = (title = spec['info']['title']) + ' ' + (version = spec['info']['version'])
      namespace = namespace.delete '(' ')' '&' '-' '+' ',' '_'
      if namespace[0] == " "
        namespace[0] = ""
      end
      spec['shared'] = shared = {
          name: namespace.gsub(' ', '_').gsub('/', '_').gsub('+', 'plus').gsub('.', '_').downcase,
          readme: !spec['info']['description'].nil? ? spec['info']['description'] : spec['info']['title']
      }
      if !spec['info']['x-logo'].nil? && !spec['info']['x-logo']['backgroundColor'].nil?
        shared['logo_background'] = spec['info']['x-logo']['backgroundColor']
      end

      scopes = []
      # Processing security, connections and roles
      create_connections_and_security(spec, shared, namespace, title, scopes)

      slugs = Set.new
      namespace_slug = namespace.delete '/' '«' '»'
      shared['namespaces'] = [
          name: namespace,
          slug: namespace_slug.squeeze(' ').gsub(' ', '_').underscore.gsub('+', 'plus').gsub('.', '_')
      ]

      #Processing parameters
      create_parameters(definitions, parameters, shared, namespace, slugs)

      #Processing webhooks
      create_webhooks(spec, paths, shared, namespace)

      begin
        Setup::Collection.data_type.create_from_json!(shared, add_only: true, primary_fields: [:name, :namespace])
        scopes.each do |scope|
          Setup::Oauth2Scope.data_type.create_from_json!(scope, add_only: true, primary_fields: [:name])
        end

      rescue Exception=> ex
        Setup::Notification.create(message: "Failed creating collection #{title}: #{ex.message}", type: :error)
      end
    end

    def identificable?(name, schema)
      schema['type'] == 'object' && (properties = schema['properties']) && properties.has_key?('id')
    end

    def check_referenced_schema(ref, container_schema, all_schemas)
      if ref_schema = all_schemas[ref]
        if identificable?(ref, ref_schema)
          container_schema['referenced'] = true
        end
      else
        flash[:error] = "ERROR: ref #{ref} not found"
      end
    end

    def check_id_property(schema)
      return schema unless schema['type'] == 'object' && !(properties = schema['properties']).nil?
      _id, id = properties.delete('_id'), properties.delete('id')
      flash[:error] = 'Defining both id and _id' if _id && id
      if _id ||= id
        naked_id = _id.reject { |k, _| %w(unique title description edi format example enum readOnly default $ref).include?(k) }
        type = naked_id.delete('type')
        flash[:error] = "Invalid id property type #{id}" unless naked_id.empty? && (type.nil? || !%w(object array).include?(type))
        schema['properties'] = properties = { '_id' => _id.merge('unique' => true,
                                                                 'title' => 'Id',
                                                                 'description' => 'Required',
                                                                 'edi' => { 'segment' => 'id' }) }.merge(properties)
        unless (required = schema['required']).present?
          required = schema['required'] = []
        end
        required.delete('_id')
        required.delete('id')
        required.unshift('_id')
      end
      properties.each { |_, property_schema| check_id_property(property_schema) if property_schema.is_a?(Hash) }
      schema
    end

    def check_definitions(definitions)
      if definitions.size > 0
        definitions.each_pair do |name, schema|
          schema['type'] = 'object' if (schema['properties']) && schema['type']== NIL
          schema['title'] = name
          if schema['type'].nil? && schema['properties'].nil?
            definitions.delete(name)
          elsif schema['type'] == 'object' && (properties = schema['properties'])
            properties.each do |property, property_schema|
              if (ref = property_schema['$ref'])
                check_referenced_schema(ref, property_schema, definitions)
              elsif property_schema['items'].is_a? Hash
                if property_schema['type'] == 'array' && (items_schema = property_schema['items']) && (ref = items_schema['$ref'])
                  check_referenced_schema(ref, property_schema, definitions)
                end
              end
            end
          end
        end
      end
    end

    def create_connections_and_security(spec, shared, namespace, title,  scopes)
      base_connections = {}
      spec ['schemes'].each do |scheme|
        base_connections[scheme] =
            {
                namespace: namespace,
                name: "#{namespace} Connection",
                url: scheme + '://' + spec['host'] + (!spec['basePath'].nil? ? spec['basePath'] : '')
            }
      end

      authorizations = []
      shared['connection_roles'] = connection_roles = []
      shared['connections'] = connections = []
      if (security_definitions = spec['securityDefinitions'])
        security_definitions.each do |name, security|
          case security['type']
            when 'oauth2'
              shared['authorizations'] = authorizations
              auth =
                  {
                      namespace: namespace,
                      name: "#{namespace} Authorization",
                      _type: 'Setup::Oauth2Authorization',
                      client: {
                          name: 'CenitSaaS',
                          provider: provider_ref = {
                              namespace: 'Cenit',
                              name: title,
                              response_type: 'code',
                              authorization_endpoint: security['authorizationUrl'],
                              token_endpoint: security['tokenUrl'],
                              token_method: 'POST',
                              _type: 'Setup::Oauth2Provider'
                          }
                      }
                  }
              security['scopes'].each do |scope, description|
                provider = {_reference: true, namespace: provider_ref[:namespace], name: provider_ref[:name] }
                scopes << { name: scope, description: description }.merge(provider: provider)
              end
              authorizations << auth

            when 'apiKey'
              shared['pull_parameters'] = pull_parameters = []
              pull_parameters <<
                  {
                      type: 'connection',
                      name: namespace+' '+ 'Connection',
                      label: 'API Key',
                      property: 'template_parameters',
                      key: 'api_key',
                      parameter: "On connection '#{namespace} Connection' template parameter 'api_key'"
                  }
            when 'basic'
              shared['authorizations'] = authorizations
              auth_basic = {
                  namespace: namespace,
                  name: "#{namespace} Authorization",
                  _type: 'Setup::BasicAuthorization'
              }
              authorizations << auth_basic
            else
              flash[:error] = "Unknown security schema: #{security['type']}"
          end
          base_connections.each do |scheme, base_connection|
            if (authorizations != [])
              connections << base_connection.merge(name: conn_name = "#{namespace} Connection",authorization: { _reference:true, namespace: namespace, name: "#{namespace} Authorization"})
              connection_roles << { namespace: namespace, name: "#{namespace}  #{scheme.upcase} Connections", connections: [{ _reference:true, namespace: namespace, name: conn_name }] }
            elsif !pull_parameters.nil?
              connections << base_connection.merge(name: conn_name = "#{namespace} Connection", template_parameters: [{ 'key':'api_key', 'value': '' }])
              connection_roles << { namespace: namespace, name: "#{namespace}  #{scheme.upcase} Connections", connections: [{ _reference:true, namespace: namespace, name: conn_name }] }
            end
          end
        end
      else
        base_connections.each do |_, base_connection|
          connections << base_connection
          connection_roles << { namespace: namespace, name: 'Connections', connections: [{ _reference: true, namespace: namespace, name: base_connection[:name] }] }
        end
      end
    end

    def create_parameters(definitions, parameters, shared, namespace, slugs)
      if definitions.size > 0 || parameters.size > 0
        shared['data_types'] =  definitions.collect do |name, schema|
          d_slug = name.delete '(' ')' '[' ']' ',' '«' '»'
          slug = d_slug.squeeze(' ').gsub(' ', '_').underscore.gsub('+', 'plus').gsub('.', '_')
          flash[:error] = "Slug already taken: #{slug}" unless slugs.add?(slug)
          {
              name: name,
              slug: slug,
              title: name.to_title,
              _type: 'Setup::JsonDataType',
              schema: check_id_property(schema),
              namespace: namespace
          }
        end +
            parameters.collect do |name, schema|
              name = name.delete '$'
              slug = 'param_' + name.squeeze(' ').gsub(' ', '_').underscore.gsub('+', 'plus').gsub('.', '_')
              flash[:error] = "Slug already taken: #{slug}" unless slugs.add?(slug)
              {
                  name: name,
                  slug: slug,
                  title: name.to_title,
                  _type: 'Setup::JsonDataType',
                  schema: check_id_property(schema),
                  namespace: {
                      _reference: true,
                      name: namespace
                  }
              }
            end
      end
    end

    def to_cenit_parameter(param)
      {
          key: param['name'],
          value: param['default'] || '',
          description: param['description'],
          metadata: param.reject { |k| %w(name description in).include?(k) }
      }
    end

    def create_webhooks(spec, paths, shared, namespace)
      default_consumes = spec['consumes'] || ['application/json']
      shared['webhooks'] = paths.keys.collect do |path|
        path_desc = paths[path]
        if (path_parameters = path_desc.delete('parameters'))
          path_parameters = path_parameters.collect do |param_desc|
            if param_desc.is_a?(Hash)
              if param_desc.size == 1 && (ref = param_desc['$ref']).is_a?(String)
                if param = parameters[ref]
                  param
                else
                  flash[:error] = "ERROR: Parameter reference not found: #{ref}"
                end
              else
                param_desc
              end
            else
              flash[:error] = "ERROR: Invalid parameter description type: #{param_desc.class}"
            end
          end
        end
        path_desc.keys.collect do |method|
          request_desc = path_desc[method]
          name = method.upcase + ' ' + path.split('/').collect { |token| token.capitalize }.join(' ')
          webhook =
              {
                  namespace: namespace,
                  name: name,
                  description: request_desc['description'],
                  method: method,
                  path: path.gsub('{', '{{').gsub('}', '}}'),
                  metadata: request_desc.reject { |k| %w(description parameters).include?(k) }.reverse_merge('consumes' => default_consumes)
              }
          location_map =
              {
                  'header' => 'headers',
                  'query' => 'parameters',
                  'path' => 'template_parameters'
              }
          [path_parameters || [], request_desc['parameters'] || []].each do |params|
            params.each do |param|
              if location = location_map[param['in']]
                unless a = webhook[location]
                  webhook[location] = a = []
                end
                a << to_cenit_parameter(param)
              end
            end
          end
          webhook
        end
      end.flatten
    end

  end
end
