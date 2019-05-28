module Setup
  class ApiSpec
    include SharedEditable

    build_in_data_type.referenced_by(:name)

    shared_allow :swagger

    field :title, type: String
    field :url, type: String
    field :specification, type: String

    before_save :validate_specification

    def validate_specification
      if specification.blank? && url.present?
        begin
          self.specification = Setup::Connection.get(url).submit!
        rescue Exception => ex
          errors.add(:base, "Unable to retrieve specification from #{url}: #{ex.message}")
        end
      end
      begin
        json = JSON.parse(specification)
        self.specification = json.to_yaml
      rescue Exception
        begin
          json = Psych.load(specification)
        rescue Exception
          json = nil
        end
      end
      if json.is_a?(Hash)
        if (swagger_version = json['swagger'])
          if swagger_version.to_s.to_f == 2.0
            if title.blank? && (info = json['info']) && (title = info['title'].to_s.strip).present?
              if (version = info['version'].to_s.strip).present?
                title = "#{title} API #{version}"
              end
              self.title = title
            end
          else
            errors.add(:specification, I18n.t('cenit.api_spec.specification.unsupported_swagger_version', swagger_version: swagger_version))
          end
        else
          errors.add(:specification, I18n.t('cenit.api_spec.specification.swagger_version_missing'))
        end
      else
        errors.add(:specification, I18n.t('cenit.api_spec.specification.invalid_format'))
      end
      errors.blank?
    end

    def cenit_collection_hash(options = {})
      self.class.swagger_to_cenit(specification, options)
    end

    def pull_asynchronous
      true
    end

    class << self
      def swagger_to_cenit(spec, options = {})
        spec = Psych.load(spec)
        [
          definitions = spec['definitions'] || {},
          parameters = spec['parameters'] || {},
          paths = spec['paths'] || {}
        ].each do |schema_container|
          schema_container.each_deep_pair do |hash, key, value|
            if key == '$ref' && !(value.is_a? Hash)
              if value.start_with?(prefix = '#/definitions/') || value.start_with?(prefix = '#/parameters/')
                hash[key] = value.from(prefix.length)
              elsif value.start_with?('#/')
                hash[key] = value.from(2)
              else
                fail "Reference #{value} is not valid"
              end
            end
            true
          end if schema_container
        end

        parameters.each { |param| fail I18n.t('cenit.api_spec.swagger_parser.error.parameter_name_conflict', param: param) if definitions.key?(param) }

        if definitions.size.positive?
          definitions.each_pair do |name, schema|
            schema['type'] = 'object' if schema['properties'] && schema['type'].nil?
            schema['title'] = name
            if schema['type'].nil? && schema['properties'].nil?
              definitions.delete(name)
              notify(:warning, I18n.t('cenit.api_spec.swagger_parser.warning.typeless_schema', schema_name: name), options)
            elsif schema['type'] == 'object' && (properties = schema['properties'])
              properties.each do |_, property_schema|
                if (ref = property_schema['$ref'])
                  check_referenced_schema(ref, property_schema, definitions, options)
                elsif property_schema['items'].is_a? Hash
                  if property_schema['type'] == 'array' && (items_schema = property_schema['items']) && (ref = items_schema['$ref'])
                    check_referenced_schema(ref, property_schema, definitions, options)
                  end
                end
              end
            else
              notify(:warning, I18n.t('cenit.api_spec.swagger_parser.warning.no_object_schema', schema_name: name), options)
            end
          end
        else
          notify(:warning, I18n.t('cenit.api_spec.swagger_parser.warning.no_definitions'), options)
        end

        title = spec['info']['title']
        title += ' API' unless title.downcase['api']
        version = spec['info']['version']
        namespace = "#{title} #{version}".strip
        spec['shared'] = shared =
          {
            name: slugify(namespace),
            shared_version: '0.1',
            readme: I18n.t('cenit.api_spec.swagger_parser.readme'),
            title: namespace,
            summary: spec['info']['description'] || spec['info']['title'],
            authors: [
              {
                name: User.current.name,
                email: User.current.email
              }
            ],
            category: 'API Collection'
          }

        # if !spec['info']['x-logo'].nil? && !spec['info']['x-logo']['backgroundColor'].nil?
        #   shared['logo_background'] = spec['info']['x-logo']['backgroundColor']
        # end

        shared['data'] = data = {}

        base_connections = {}
        multiple_schemes = spec ['schemes'].size > 1
        spec['schemes'].each do |scheme|
          base_connections[scheme] =
            {
              namespace: namespace,
              name: multiple_schemes ? "#{scheme.upcase} Connection" : 'Connection',
              url: scheme + '://' + spec['host'] + (!spec['basePath'].nil? ? spec['basePath'] : '')
            }
        end

        slugs = Set.new
        namespace_slug = slugify(namespace)
        namespaces = { namespace => namespace_slug }

        connections_params = {}
        parameters.values.each do |param|
          (connections_params[LOCATION_MAP[param['in']]] ||= []) << to_cenit_parameter(param)
        end

        data['connection_roles'] = connection_roles = []
        data['connections'] = connections = []

        oauth_providers = {}
        oauth_clients = {}
        authorizations = []
        current_oauth2_scopes = []
        if (security_definitions = spec['securityDefinitions']).present?
          multiple_security = security_definitions.size > 1
          security_definitions.each do |name, security|
            name = name.to_title
            pull_parameters = nil
            case (security_type = security['type'])
            when 'oauth2', 'oauth1'
              data['authorizations'] = authorizations
              provider_model =
                if security_type == 'oauth1'
                  Setup::OauthProvider
                else
                  Setup::Oauth2Provider
                end
              fail I18n.t('cenit.api_spec.swagger_parser.error.authorization_url_missing') unless (auth_url = security['authorizationUrl'])
              provider = oauth_providers[auth_url] ||
                         provider_model.where(authorization_endpoint: auth_url).first ||
                         (oauth_providers_config.key?(auth_url) && provider_model.new_from_json(oauth_providers_config[auth_url]))
              provider.authorization_endpoint = auth_url
              provider.namespace ||= 'Cenit'
              if provider
                client = oauth_clients[auth_url] ||
                         Setup::RemoteOauthClient.where(provider: provider).first ||
                         Setup::RemoteOauthClient.new(provider: provider, name: 'Client')
                oauth_clients[auth_url] = client
                oauth_providers[auth_url] = provider
                unless namespaces.key?(provider.namespace)
                  namespaces[provider.namespace] = provider.ns_slug
                end
                auth =
                  {
                    namespace: namespace,
                    name: "#{name} Authorization",
                    _type: 'Setup::Oauth2Authorization',
                    client: {
                      _reference: true,
                      name: client.name,
                      provider: provider_ref = {
                        _reference: true,
                        namespace: provider.namespace,
                        name: provider.name
                      }
                    },
                    scopes: scopes = []
                  }
                security['scopes'].each do |scope, description|
                  scopes << { _reference: true, name: scope }.merge(provider: provider_ref)
                  current_oauth2_scopes << { name: scope, description: description }.merge(provider: provider_ref)
                end
                authorizations << auth
              else
                fail I18n.t('cenit.api_spec.swagger_parser.error.oauth_provider_config_missing', auth_url: auth_url)
              end
            when 'apiKey'
              shared[:pull_parameters] = pull_parameters = []
              pull_parameters <<
                {
                  property_name: 'value',
                  label: 'API Key',
                  properties_locations: [
                    {
                      connections: {
                        namespace: namespace,
                        name: 'Connection'
                      },
                      template_parameters: {
                        key: 'api_key'
                      }
                    }
                  ]
                }
            when 'basic'
              data['authorizations'] = authorizations
              auth_basic = {
                namespace: namespace,
                name: "#{name} Authorization",
                _type: 'Setup::BasicAuthorization'
              }
              authorizations << auth_basic
            else
              fail I18n.t('cenit.api_spec.swagger_parser.error.unsupported_security_type', security_type: security_type)
            end

            base_connections.each do |scheme, base_connection|
              conn = base_connection.dup
              if multiple_security
                conn[:name] = "#{name} Connection"
              end
              if pull_parameters
                conn[:template_parameters] = [{ 'key': 'api_key', 'value': '' }]
              end
              connections << conn
              conn_role_name = 'Connections'
              conn_role_name = "#{name} #{conn_role_name}" if multiple_security
              conn_role_name = "#{scheme.upcase} #{conn_role_name}" if multiple_schemes
              connection_roles <<
                {
                  namespace: namespace,
                  name: conn_role_name,
                  connections: [{ _reference: true, namespace: namespace, name: conn[:name] }]
                }
            end
          end
        else
          notify(:warning, I18n.t('cenit.api_spec.swagger_parser.warning.no_security'), options)
          base_connections.each do |scheme, base_connection|
            connections << base_connection
            connection_roles << { namespace: namespace, name: "#{scheme.upcase} Connections", connections: [{ _reference: true, namespace: namespace, name: base_connection[:name] }] }
          end
        end
        {
          oauth_clients: oauth_clients,
          oauth_providers: oauth_providers
        }.each do |entry, container|
          data[entry] = container.values.collect do |record|
            if record.new_record?
              record.share_hash
            else
              { id: record.id.to_s }
            end
          end
        end

        if definitions.size.positive? || parameters.size.positive?
          data['snippets'] = snippets = []
          data['data_types'] = data_types = []
          {
            '': definitions,
            param_: parameters
          }.each do |slug_prefix, schemas|
            schemas.each do |name, schema|
              name = name.delete '$'
              slug = slug_prefix.to_s + slugify(name)
              fail "Slug name clash: #{slug}" unless slugs.add?(slug)
              data_type = Setup::JsonDataType.new namespace: namespace,
                                                  name: name,
                                                  slug: slug,
                                                  title: name.to_title
              data_type.schema = schema
              if data_type.validate_model
                data_type.snippet.namespace = namespace
                data_type.snippet.name = data_type.snippet_name
                data_type.snippet.type = :javascript
                snippets << data_type.snippet.share_hash
                data_types << data_type.share_hash
              else
                fail I18n.t('cenit.api_spec.swagger_parser.error.invalid_data_type_schema', schema_name: name, reason: data_type.errors.full_messages.to_sentence)
              end
            end
          end
        end

        default_consumes = spec['consumes'] || ['application/json']

        data['operations'] = operations = []
        resources = {}
        paths.each do |path, path_desc|
          path = path.squeeze('/')
          path.chop! if path.end_with?('/')
          path_parameters = { template_parameters: template_parameters = [] }.stringify_keys
          (path_desc.delete('parameters') || []).each do |param_desc|
            if param_desc.is_a?(Hash)
              if param_desc.size == 1 && (ref = param_desc['$ref']).is_a?(String)
                if (param = parameters[ref])
                  param_desc = param
                else
                  fail I18n.t('cenit.api_spec.swagger_parser.error.missing_parameter_path_ref', path: path, ref: ref)
                end
              end
              (path_parameters[LOCATION_MAP[param_desc['in']]] ||= []) << to_cenit_parameter(param_desc)
            else
              fail I18n.t('cenit.api_spec.swagger_parser.error.invalid_parameter_path_description_type', path: path, type: param_desc.class)
            end
          end
          if (resource = resources[path])
            resource_name = resource[:name]
            resource_operations_refs = resource[:operations]
          else
            resources[path] = resource = {
              namespace: namespace,
              name: resource_name = path.split('/').collect(&:capitalize).join(' ').strip,
              path: path.gsub('{', '{{').gsub('}', '}}'),
              operations: resource_operations_refs = [],
              _reset: :operations,
              metadata: {}
            }
          end
          resource_operations = path_desc.keys.collect do |method|
            request_desc = path_desc[method]
            method = method.to_s.downcase
            operation =
              {
                resource: resource_ref = {
                  _reference: true,
                  namespace: namespace,
                  name: resource_name
                },
                _type: Setup::Operation.to_s,
                method: method,
                parameters: [],
                headers: [],
                metadata: metadata = request_desc.reject { |k| %w(description parameters).include?(k) }.reverse_merge('consumes' => default_consumes)
              }
            resource_operations_refs <<
              {
                _reference: true,
                resource: resource_ref,
                method: method
              }
            if (description = request_desc['description'])
              operation[:description] = description
            end
            metadata[:template_parameters] = []
            (request_desc['parameters'] || []).each do |param_desc|
              if param_desc.is_a?(Hash)
                if param_desc.size == 1 && (ref = param_desc['$ref']).is_a?(String)
                  if (param_desc = parameters[ref])
                    param_desc = param_desc
                  else
                    fail I18n.t('cenit.api_spec.swagger_parser.error.missing_operation_path_parameter_ref', operation: method.upcase, path: path, ref: ref)
                  end
                end
                location = LOCATION_MAP[param_desc['in']]
                if location == :template_parameters
                  metadata[:template_parameters]
                else
                  operation[location] ||= []
                end << to_cenit_parameter(param_desc)
              else
                fail I18n.t('cenit.api_spec.swagger_parser.error.invalid_operation_parameter_path_description_type', operation: method.upcase, path: path, type: param_desc.class)
              end
            end
            operation
          end
          template_parameters = template_parameters.inject({}) { |h, p| h[p[:key]] = p; h }
          resource_operations.each do |op|
            op[:metadata][:template_parameters].each do |p|
              template_parameters[p[:key]] =
                if (template_parameter = template_parameters[p[:key]])
                  template_parameter.intersection(p)
                else
                  p
                end
            end
          end
          resource_operations.each do |op|
            op_template_parameters = {}
            op[:metadata].delete(:template_parameters).each do |p|
              if (p = template_parameters[(key = p[:key])].difference(p)).present?
                op_template_parameters[key] = p
              end
            end
            if op_template_parameters.present?
              op[:metadata][:template_parameters] = op_template_parameters
            end
          end
          path_parameters['template_parameters'] = template_parameters.values.to_a
          resource.merge!(path_parameters)
          factorize_params(resource, resource_operations)
          operations.concat(resource_operations)
        end
        data['resources'] = resources.values

        factorize_params(connections_params, data['resources'])
        connections_params.each do |params_key, params|
          connections_params[params_key] = params.inject({}) { |h, p| h[p[:key]] = p; h }
        end
        connections.each do |connection|
          connections_params.each do |params_key, params|
            conn_params = (connection.delete(params_key) || []).inject({}) { |h, p| h[p[:key]] = p; h }
            conn_params.deep_merge!(params)
            connection[params_key] = conn_params.values.to_a
          end
        end

        data['namespaces'] = namespaces.collect do |name, slug|
          {
            name: name,
            slug: slug
          }
        end

        data['oauth2_scopes'] = current_oauth2_scopes unless current_oauth2_scopes.empty?

        data['metadata'] = { info: spec['info'] }

        unless options[:shared_format]
          [:name, :readme, :title].each { |key| data[key] = shared[key] }
          shared = data
        end

        shared = Cenit::Utility.stringfy(shared)

        %w(connections resources operations).each do |entry|
          next unless (items = shared[entry])
          items.each do |item|
            %w(parameters headers template_parameters).each do |params_key|
              if item.key?(params_key)
                unless (reset = item['_reset'])
                  reset = []
                end
                reset = [reset] unless reset.is_a?(Array)
                reset << params_key
                item['_reset'] = reset
              end
            end
          end
        end

        shared
      end

      def oauth_providers_config
        @oauth_providers_config ||= Psych.load(File.read(filename = 'config/oauth_providers.yaml'), filename)
      end

      private

      def factorize_params(parent, childs)
        [:headers, :parameters].each { |params| factorize(params, parent, childs) }
      end

      def factorize(params, parent, children)
        return if children.blank?
        keys = Set.new((children.first[params] || []).collect { |p| p[:key] })
        if keys.present?
          children.each do |child|
            next if keys.blank?
            child_params = child[params] || []
            keys.each { |key| keys.delete(key) unless child_params.any? { |p| p[:key] == key } }
          end
        end
        if keys.present?
          parent_params = parent.delete(params) || []
          parent_params = parent_params.inject({}) { |h, p| h[p[:key]] = p; h }
          children.each do |child|
            next unless (child_params = child[params]).present?
            child_params, child[params] = child_params.partition { |child_param| keys.include?(child_param[:key]) }
            child_params.each do |child_param|
              key = child_param[:key]
              parent_params[key] =
                if (parent_param = parent_params[key])
                  parent_param.intersection(child_param)
                else
                  child_param
                end
              (child[:metadata][params] ||= []) << child_param
            end
          end
          children.each do |child|
            child_params = {}
            child[:metadata].delete(params).each do |p|
              if keys.exclude?(key = p[:key]) ||
                 (p = parent_params[key].difference(p)).present?
                child_params[key] = p
              end
            end
            if child_params.present?
              child[:metadata][params] = child_params
            end
          end
          if parent_params.present?
            parent[params] = parent_params.values.to_a
          end
        end
      end

      def notify(type, msg, opts)
        if (task = opts[:task])
          task.notify(type: type, message: msg)
        else
          opts[:notifications] ||= []
          opts[:notifications] << "#{type.to_s.upcase}: #{msg}"
        end
      end

      LOCATION_MAP =
        {
          header: :headers,
          query: :parameters,
          path: :template_parameters
        }.stringify_keys

      LOCATION_MAP.default :parameters

      def check_referenced_schema(ref, container_schema, all_schemas, options)
        if (ref_schema = all_schemas[ref])
          if identificable?(ref, ref_schema)
            container_schema['referenced'] = true
          else
            notify(:warning, I18n.t('cenit.api_spec.swagger_parser.warning.embedding_reference', ref: ref), options)
          end
        else
          fail "Reference #{ref} not found"
        end
      end

      def slugify(name)
        name = name.gsub(%r{ |\/|\.|:|-}, '_').gsub('+', 'plus').gsub('&', '_and_')
        name = name.split('_').collect do |word|
          if word.downcase.length > 10
            word.underscore
          else
            word.downcase
          end
        end.join('_').gsub(/_+/, '_')
        name.delete '(' ')' '[' ']' ',' '«' '»' ','
      end

      def to_cenit_parameter(param)
        {
          _primary: 'key',
          key: param['name'],
          value: param['default'] || '',
          description: param['description'],
          metadata: param.reject { |k| %w(name description in).include?(k) }
        }
      end

      def identificable?(_name, schema)
        schema['type'] == 'object' && (properties = schema['properties']) && properties.key?('id')
      end

    end
  end
end
