module RailsAdmin
  ###
  # Generate cURL command for api service.
  module GenerateCurlHelper
    ###
    # Get api specification from swagger.json file.
    def api_specification
      spec_url = 'https://cenit-io.github.io/openapi/swagger.json'
      @@cenit_api_spec ||= ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(open(spec_url).read))
    end

    ###
    # Get api specification paths for current namespace and model.
    def api_current_paths
      if params[:model_name].present?
        ns, model_name = params[:model_name].split(/~/)
        pattern = Regexp.new "^/#{ns}/#{model_name}"

        api_specification[:paths].select { |k, _v| k =~ pattern }
      else
        {}
      end
    end

    ###
    # Get cURL command for service with given method and path.
    def api_curl(method, path)
      # Get parameters definition.
      path_parameters, query_parameters = api_parameters(method, path)

      # Get the uri parts.
      schema, base_path, host, path = api_uri_parts(path)

      # Get security headers.
      token, token_header, key, key_header = api_security_headers

      # Set value of path parameters
      path_parameters.each { |p| path.gsub!("{#{p[:name]}}", @object.send(p[:name])) } if @object

      # Generate uri and command.
      command = "curl -X #{method.upcase} \\\n"
      command << "     -H '#{key_header}: #{key}' \\\n"
      command << "     -H '#{token_header}: #{token}' \\\n"
      command << "     -H 'Content-Type: application/json' \\\n"
      command << "     -d '#{api_data(query_parameters).to_json}' \\\n" unless query_parameters.empty?
      command << "     '#{schema}://#{host}/#{base_path}/#{path}.json'\n\n"

      URI.encode(command)
    end

    ###
    # Get parameters for service with given method and path.
    def api_parameters(method, path)
      parameters = api_specification[:paths][path][method][:parameters] || []

      # TODO: Reemplazar las referencias ($ref) por su valor real.

      path_parameters = parameters.select { |p| p[:in] == 'path' }
      query_parameters = parameters.select { |p| p[:in] == 'query' }

      [path_parameters, query_parameters]
    end

    ###
    # Get the uri parts.
    def api_uri_parts(path)
      if Rails.env.development?
        schema = 'http'
        host = '127.0.0.1:3000'
      else
        schema = @@cenit_api_spec[:schemes].first
        host = @@cenit_api_spec[:host].chomp('/')
      end
      base_path = @@cenit_api_spec[:basePath].chomp('/').reverse.chomp('/').reverse
      path = path.reverse.chomp('/').reverse

      [schema, base_path, host, path]
    end

    ###
    # Get security headers.
    def api_security_headers
      token = Account.current.token
      token_header = @@cenit_api_spec[:securityDefinitions]['X-User-Access-Token'][:name]
      key = Account.current.key
      key_header = @@cenit_api_spec[:securityDefinitions]['X-User-Access-Key'][:name]

      [token, token_header, key, key_header]
    end

    ###
    # Get data object from service parameters definition.
    def api_data(parameters)
      data = {}
      parameters.each { |p| data[p[:name]] = api_default_param_value(p[:type]) }
      data
    end

    ###
    # Get default value from parameter type.
    def api_default_param_value(param_type)
      values = { 'integer' => 0, 'number' => 0, 'real' => 0, 'boolean' => false, 'object' => {}, 'array' => [] }
      values[param_type] || ''
    end
  end
end
