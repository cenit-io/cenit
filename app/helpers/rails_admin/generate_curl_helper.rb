module RailsAdmin
  ###
  # Generate cURL command for api service.
  module GenerateCurlHelper
    ###
    # Returns api specification paths for current namespace and model.
    def api_current_paths
      @api_current_paths ||= begin
        if params[:model_name].start_with?('dt')
          ns, model_name, data_type = api_model_from_data_type
          display_name = data_type.name.chomp('.json').humanize
        else
          ns, model_name = params[:model_name].split(/~/)
          display_name = model_name.humanize
        end

        {
          "#{ns}/#{model_name}/{id}" => {
            get: api_spec_for_get(display_name),
            delete: api_spec_for_delete(display_name)
          },
          "#{ns}/#{model_name}/{id}/{view}" => {
            get: api_spec_for_get_with_view(display_name)
          },
          "#{ns}/#{model_name}" => {
            get: api_spec_for_list(display_name),
            post: api_spec_for_create(display_name, data_type)
          }
        }

      end if params[:model_name].present?
    rescue
      nil
    end

    ###
    # Returns cURL command for service with given method and path.
    def api_curl(method, path)
      # Get parameters definition.
      path_parameters, query_parameters = api_parameters(method, path)

      # Get data object from query parameters.
      data = query_parameters.map { |p| [p[:name], api_default_param_value(p)] }.to_h

      # Generate uri and command.
      command = "curl -X #{method.upcase} \\\n"
      command << "     -H 'X-User-Access-Key: #{Account.current.key}' \\\n"
      command << "     -H 'X-User-Access-Token: #{Account.current.token}' \\\n"
      command << "     -H 'Content-Type: application/json' \\\n"
      command << "     -d '#{data.to_json}' \\\n" unless data.empty?
      command << "     '#{api_uri(path, path_parameters)}'\n\n"

      URI.encode(command)
    end

    protected

    ###
    # Returns parameters for service with given method and path.
    def api_parameters(method, path)
      parameters = api_current_paths[path][method][:parameters] || []

      path_parameters = parameters.select { |p| p[:in] == 'path' }
      query_parameters = parameters.select { |p| p[:in] == 'query' }

      [path_parameters, query_parameters]
    end

    ###
    # Returns default value from parameter.
    def api_default_param_value(param)
      values = { 'integer' => 0, 'number' => 0, 'real' => 0, 'boolean' => false, 'object' => {}, 'array' => [] }
      param[:default] || values[param[:type]] || ''
    end

    ###
    # Returns api uri.
    def api_uri(path, path_parameters)
      uri = (Rails.env.development? ? 'http://127.0.0.1:3000' : 'https://cenit.io') + "/api/v2/#{path}"

      # Set value of uri path parameters
      path_parameters.each do |p|
        if @object.respond_to?(p[:name])
          value = @object.send(p[:name])
          uri.gsub!("{#{p[:name]}}", value) unless value.to_s.empty?
        end
      end if @object

      uri
    end

    ###
    # Returns service get specification.
    def api_spec_for_get(display_name)
      {
        tags: [display_name],
        summary: "Retrieve an existing '#{display_name}'",
        description: [
          "Retrieves the details of an existing '#{display_name}'.",
          "You need only supply the unique '#{display_name}' identifier",
          "that was returned upon '#{display_name}' creation."
        ].join(' '),
        parameters: [{ description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true }]
      }
    end

    ###
    # Returns service get specification with view parameter.
    def api_spec_for_get_with_view(display_name)
      {
        tags: [display_name],
        summary: "Retrieve one attribute of an existing '#{display_name}'",
        description: "Retrieves one attribute of an existing '#{display_name}'.",
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true },
          { description: 'Attribute name', in: 'path', name: 'view', type: 'string', required: true }
        ]
      }
    end

    ###
    # Returns service delete specification.
    def api_spec_for_delete(display_name)
      {
        tags: [display_name],
        summary: "Delete an existing '#{display_name}'",
        description: "Permanently deletes an existing '#{display_name}'. It cannot be undone.",
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true }
        ]
      }
    end

    ###
    # Returns service list specification.
    def api_spec_for_list(display_name)
      limit = Kaminari.config.default_per_page

      {
        tags: [display_name],
        summary: "Retrieve all existing '#{display_name.pluralize}'",
        description: "Retrieve all existing '#{display_name.pluralize}' you've previously created.",
        parameters: [
          { description: 'Page number', in: 'query', name: 'page', type: 'integer', default: 1 },
          { description: 'Page size', in: 'query', name: 'limit', type: 'integer', default: limit },
          { description: 'Items order', in: 'query', name: 'order', type: 'string', default: 'id' },
          { description: 'JSON Criteria', in: 'query', name: 'where', type: 'string', default: '{}' }
        ]
      }
    end

    ###
    # Returns service create or update specification.
    def api_spec_for_create(display_name, data_type = nil)
      parameters = data_type ? api_params_from_data_type(data_type) : api_params_from_current_model

      {
        tags: [display_name],
        summary: "Create or update an '#{display_name}'",
        description: [
          "Creates or updates the specified '#{display_name}'.",
          'Any parameters not provided will be left unchanged'
        ].join(' '),
        parameters: [{ description: 'Identifier', in: 'path', name: 'id', type: 'string' }] + parameters
      }
    end

    ###
    # Returns prepared parameters from data type code properties.
    def api_params_from_data_type(data_type)
      code = JSON.parse(data_type.code)
      code['properties'].map { |k, v| { in: 'query', name: k, type: v['type'] } }
    end

    ###
    # Returns prepared parameters from current model properties.
    def api_params_from_current_model
      exclude = /^(created_at|updated_at|version|origin)$|_ids?$/
      params = @properties.map { |p| { in: 'query', name: p.property.name, type: p.property.type } }
      params.select { |p| !p[:name].match(exclude) }
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
