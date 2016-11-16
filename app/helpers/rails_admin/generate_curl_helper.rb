module RailsAdmin
  ###
  # Generate cURL command for api service.
  module GenerateCurlHelper
    ###
    # Returns api specification from swagger.json file.
    def api_specification
      @@cenit_api_spec ||= begin
        spec_url = 'https://cenit-io.github.io/openapi/swagger.json'
        ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(open(spec_url).read))
      end

      api_specification_for_data_types if @@cenit_api_spec && params[:model_name].start_with?('dt')

      @@cenit_api_spec
    rescue
      false
    end

    ###
    # Returns custom api specification for data_type model.
    def api_specification_for_data_types
      ns, model_name, data_type = api_model_from_data_type

      @@cenit_api_spec[:paths]["/#{ns}/#{model_name}/{id}"] = {
        get: api_data_type_spec_get(data_type),
        delete: api_data_type_spec_delete(data_type)
      }

      @@cenit_api_spec[:paths]["/#{ns}/#{model_name}/{id}/{view}"] = {
        get: api_data_type_spec_get_with_view(data_type)
      }

      @@cenit_api_spec[:paths]["/#{ns}/#{model_name}"] = {
        get: api_data_type_spec_list(data_type),
        post: api_data_type_spec_create(data_type)
      }
    end

    ###
    # Returns api specification paths for current namespace and model.
    def api_current_paths
      spec = api_specification
      if params[:model_name].present? && spec
        ns, model_name = params[:model_name].start_with?('dt') ? api_model_from_data_type : params[:model_name].split(/~/)
        pattern = Regexp.new "^/#{ns}/#{model_name}"

        spec[:paths].select { |k, _v| k =~ pattern }
      else
        {}
      end
    end

    ###
    # Returns cURL command for service with given method and path.
    def api_curl(method, path)
      # Get parameters definition.
      path_parameters, query_parameters = api_parameters(method, path)

      # Get the uri parts.
      schema, base_path, host, path = api_uri_parts(path)

      # Get security headers.
      token, token_header, key, key_header = api_security_headers

      # Set value of path parameters
      path_parameters.each do |p|
        path.gsub!("{#{p[:name]}}", @object.send(p[:name])) if @object.respond_to?(p[:name])
      end if @object

      # Generate uri and command.
      command = "curl -X #{method.upcase} \\\n"
      command << "     -H '#{key_header}: #{key}' \\\n"
      command << "     -H '#{token_header}: #{token}' \\\n"
      command << "     -H 'Content-Type: application/json' \\\n"
      command << "     -d '#{api_data(query_parameters).to_json}' \\\n" unless query_parameters.empty?
      command << "     '#{schema}://#{host}/#{base_path}/#{path}'\n\n"

      URI.encode(command)
    end

    ###
    # Returns parameters for service with given method and path.
    def api_parameters(method, path)
      parameters = api_specification[:paths][path][method][:parameters] || []

      # TODO: Reemplazar las referencias ($ref) por su valor real.

      path_parameters = parameters.select { |p| p[:in] == 'path' }
      query_parameters = parameters.select { |p| p[:in] == 'query' }

      [path_parameters, query_parameters]
    end

    ###
    # Returns the uri parts.
    def api_uri_parts(path)
      if Rails.env.development?
        schema = 'http'
        host = '127.0.0.1:3000'
      else
        schema = @@cenit_api_spec[:schemes].first
        host = @@cenit_api_spec[:host].chomp('/')
      end
      base_path = @@cenit_api_spec[:basePath].sub(%r{^/|/$}, '')
      path = path.sub(%r{^/}, '')

      [schema, base_path, host, path]
    end

    ###
    # Returns security headers.
    def api_security_headers
      token = Account.current.token
      token_header = @@cenit_api_spec[:securityDefinitions]['X-User-Access-Token'][:name]
      key = Account.current.key
      key_header = @@cenit_api_spec[:securityDefinitions]['X-User-Access-Key'][:name]

      [token, token_header, key, key_header]
    end

    ###
    # Returns data object from service parameters definition.
    def api_data(parameters)
      data = {}
      parameters.each { |p| data[p[:name]] = api_default_param_value(p) }
      data
    end

    ###
    # Returns default value from parameter.
    def api_default_param_value(param)
      values = { 'integer' => 0, 'number' => 0, 'real' => 0, 'boolean' => false, 'object' => {}, 'array' => [] }
      param[:default] || values[param[:type]] || ''
    end

    ###
    # Returns data type service get specification.
    def api_data_type_spec_get(data_type)
      name = data_type.name.chomp('.json').humanize

      {
        tags: [name],
        summary: "Retrieve an existing #{name}",
        description: [
          "Retrieves the details of an existing #{name}.",
          "You need only supply the unique #{name} identifier",
          "that was returned upon #{name} creation."
        ].join(' '),
        parameters: [{ description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true }]
      }
    end

    ###
    # Returns data type service get specification.
    def api_data_type_spec_get_with_view(data_type)
      name = data_type.name.chomp('.json').humanize

      {
        tags: [name],
        summary: "Retrieve one attribute of an existing #{name}",
        description: "Retrieves one attribute of an existing #{name}.",
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true },
          { description: 'Attribute name', in: 'path', name: 'view', type: 'string', required: true }
        ]
      }
    end

    ###
    # Returns data type service delete specification.
    def api_data_type_spec_delete(data_type)
      name = data_type.name.chomp('.json').humanize

      {
        tags: [name],
        summary: "Delete an existing #{name}",
        description: "Permanently deletes an existing #{name}. It cannot be undone.",
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true }
        ]
      }
    end

    ###
    # Returns data type service list specification.
    def api_data_type_spec_list(data_type)
      name = data_type.name.chomp('.json').humanize.pluralize
      limit = Kaminari.config.default_per_page

      {
        tags: [name],
        summary: "Retrieve all existing #{name}",
        description: "Retrieve all existing #{name} you've previously created.",
        parameters: [
          { description: 'Page number', in: 'query', name: 'page', type: 'integer', required: false, default: 1 },
          { description: 'Page size', in: 'query', name: 'limit', type: 'integer', required: false, default: limit },
          { description: 'Items order', in: 'query', name: 'order', type: 'string', required: false, default: 'id' },
          { description: 'JSON Criteria', in: 'query', name: 'where', type: 'string', required: false, default: '{}' }
        ]
      }
    end

    ###
    # Returns data type service create or update specification.
    def api_data_type_spec_create(data_type)
      name = data_type.name.chomp('.json').humanize
      code = JSON.parse(data_type.code)
      parameters = code['properties'].map { |k, v| { in: 'query', name: k, type: v['type'], required: false } }

      {
        tags: [name],
        summary: "Create or update an #{name}",
        description: [
          "Creates or updates the specified #{name}.",
          'Any parameters not provided will be left unchanged'
        ].join(' '),
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string', required: false }
        ] + parameters
      }
    end

    ###
    # Returns current namespace, model name and data type instance.
    def api_model_from_data_type
      data_type = Setup::DataType.find(params[:model_name].from(2))
      ns = data_type.namespace.parameterize.underscore.downcase
      model_name = data_type.slug

      [ns, model_name, data_type]
    end
  end
end
