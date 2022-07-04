require 'openapi3_parser'

module Setup
  class ApiSpec
    include SharedEditable

    build_in_data_type.referenced_by(:name)

    field :title, type: String
    field :url, type: String
    field :specification, type: String

    validate :validate_specification
    validates_presence_of :specification

    before_save :parse_title

    def spec_doc
      @spec_doc ||= Openapi3Parser.load(specification)
      @spec_doc
    end

    def parse_title
      self.title = spec_doc.info.title if title.blank?
    end

    def validate_specification
      specification.strip!

      if url.present? && specification.blank?
        begin
          self.specification = Setup::Connection.get(url).submit!
        rescue Exception => ex
          errors.add(:base, "Unable to retrieve specification from #{specification}: #{ex.message}")
        end
      end

      return if specification.blank?

      spec = self.spec_doc

      if spec.valid?
        self.specification = spec.root_source.data.to_yaml
      else
        errors.add(:specification, "in not valid, #{spec.errors.map(&:message).uniq.join(', ')}.")
      end
    end

    def cenit_collection_hash(options = {})
      spec = self.spec_doc
      c_title = self.title || spec.info.title
      name = slugify(c_title)
      namespace = name.camelize
      current_user = ::User.current

      collection = {
        name: name,
        shared_version: '0.1',
        readme: I18n.t('cenit.api_spec.swagger_parser.readme'),
        title: c_title,
        summary: spec.info.description || c_title,
        authors: [{ name: current_user.name, email: current_user.email }],
        category: 'API Collection',
        namespaces: [{ _primary: ['name'], slug: name, name: namespace }],
        connections: [],
        webhooks: [],
        oauth_providers: [],
        oauth_clients: [],
        oauth2_scopes: [],
        authorizations: [],
      }

      parse_authorizations(namespace, collection)
      parse_connections(namespace, collection)
      parse_webhooks(namespace, collection)

      collection
    end

    def pull_asynchronous
      true
    end

    protected

    def parse_authorizations(namespace, collection)
      spec = self.spec_doc
      find_security_scheme = ->(type) { spec.components.security_schemes.detect { |_, v| v.type == type.to_s }.last }

      if (security_scheme = find_security_scheme.call(:oauth2))
        parse_oaut2_providers(namespace, collection, security_scheme)
        parse_oaut2_clients(namespace, collection, security_scheme)
        parse_oaut2_scopes(namespace, collection, security_scheme)
        parse_oaut2_authorization(namespace, collection, security_scheme)
      elsif (security_scheme = find_security_scheme.call(:http))
        parse_basic_authorization(namespace, collection, security_scheme)
      end
    end

    def parse_basic_authorization(namespace, collection, security_scheme)
      collection[:authorizations] << {
        _primary: %w[namespace name],
        namespace: namespace,
        name: 'default_authorization',
        _type: 'Setup::BasicAuthorization'
      }
    end

    def parse_oaut2_authorization(namespace, collection, security_scheme)
      options = security_scheme.flows.authorization_code
      client = collection[:oauth_clients].first
      provider = client[:provider]

      collection[:authorizations] << {
        _primary: %w[namespace name],
        namespace: namespace,
        name: 'default_authorization',
        _type: 'Setup::Oauth2Authorization',
        token_type: 'bot',
        client: { _reference: true, _type: client[:_type], name: client[:name], provider: provider },
        parameters: [],
        template_parameters: [{ _primary: %w[key], key: "scopes", value: options.scopes.values.join(',') }],
        scopes: [{ _reference: true, name: '{{scopes}}', provider: provider }]
      }
    end

    def parse_oaut2_providers(namespace, collection, security_scheme)
      options = security_scheme.flows.authorization_code

      collection[:oauth_providers] << {
        _primary: %w[namespace name],
        _type: 'Setup::Oauth2Provider',
        origin: 'default',
        namespace: namespace,
        name: 'default_provider',
        authorization_endpoint: options.authorization_url,
        response_type: 'code',
        token_endpoint: options.token_url,
        token_method: 'POST',
        refresh_token_strategy: 'default',
        scope_separator: ','
      }
    end

    def parse_oaut2_clients(namespace, collection, security_scheme)
      provider = collection[:oauth_providers].first
      provider = { _reference: true, namespace: provider[:namespace], name: provider[:name] }

      collection[:oauth_clients] << {
        _primary: %w[_type provider name],
        _type: 'Setup::RemoteOauthClient',
        name: 'default_client',
        provider: provider,
        request_token_parameters: [],
        request_token_headers: [],
        template_parameters: []
      }
    end

    def parse_oaut2_scopes(namespace, collection, security_scheme)
      provider = collection[:oauth_providers].first
      provider = { _reference: true, namespace: provider[:namespace], name: provider[:name] }

      collection[:oauth2_scopes] << { _primary: %w[name provider], name: "{{scopes}}", provider: provider }
    end

    def parse_connections(namespace, collection)
      spec = self.spec_doc
      auth = collection[:authorizations].first

      collection[:connections] << conn = {
        _primary: %w[namespace name],
        namespace: namespace,
        name: 'default_connection',
        url: spec.servers.first.try(:url) || "http://#{collection.name}.domain.com",
        headers: [],
        parameters: [],
      }

      unless auth.nil?
        conn[:authorization] = { _reference: true, namespace: auth[:namespace], name: auth[:name] }

        if (auth[:_type] == 'Setup::Oauth2Authorization')
          conn[:authorization_handler] = true
          conn[:headers] << { key: 'Authorization', value: 'Bearer {{access_token}}' }
        end
      end

      spec.components.security_schemes.each do |_, scheme|
        next unless scheme.type == 'apiKey'

        tp_name = slugify(scheme.name)
        item = { key: scheme.name, value: "{{#{tp_name}}}" }

        if scheme.in == 'header'
          conn[:headers] << item
        elsif scheme.in == 'query'
          conn[:parameters] << item
        end
      end
    end

    def parse_webhooks(namespace, collection)
      spec = self.spec_doc
      namespace = collection[:namespaces].first[:name]

      spec.paths.each do |path, path_spec|
        spec.paths[path].each do |method, service_spec|
          next if service_spec.nil? || method !~ /^(get|post|put|patch|delete|options)$/

          headers = parse_webhook_parameters(path_spec, 'header')
          headers.concat(parse_webhook_parameters(service_spec, 'header'))
          parameters = parse_webhook_parameters(path_spec, 'query')
          parameters.concat(parse_webhook_parameters(service_spec, 'query'))
          template_parameters = parse_webhook_template_parameters(path_spec)
          template_parameters.concat(parse_webhook_template_parameters(service_spec))

          collection[:webhooks] << {
            namespace: namespace,
            name: service_spec.operation_id || "#{method}_#{slugify(path)}",
            method: method,
            path: path.gsub(/\{([^\}]+)\}/, '{{\1}}'),
            description: "#{service_spec.summary}\n\n#{service_spec.description}".strip,
            headers: headers,
            parameters: parameters,
            template_parameters: template_parameters,
          }
        end
      end

    end

    def parse_webhook_parameters(spec, filter = 'query')
      spec.parameters.select { |p| p.in == filter }.map do |p|
        { key: p.name, value: "{{#{p.name}}}", description: p.description }
      end
    end

    def parse_webhook_template_parameters(service_spec)
      service_spec.parameters.map do |p|
        { key: p.name, value: p.schema.example ? JSON.generate(p.schema.example) : '', description: p.description }
      end
    end

    def slugify(name)
      name.underscore.parameterize.underscore
    end
  end
end
