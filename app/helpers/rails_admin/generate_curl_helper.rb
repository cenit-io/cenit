module RailsAdmin
  module GenerateCurlHelper

    ###
    # Get api specification from swagger.json file.
    def api_specification
      @@cenit_api_spec ||= ActiveSupport::HashWithIndifferentAccess.new(
          JSON.parse(open('https://cenit-io.github.io/openapi/swagger.json').read)
      )
    end

    ###
    # Get api specification paths for current namespace and model.
    def api_current_paths
      if (params[:model_name].present?)
        ns, model_name = params[:model_name].split(/~/)
        pattern = Regexp.new "^/#{ns}/#{model_name}"

        api_specification[:paths].select { |k, v| k =~ pattern }
      else
        {}
      end
    end

    ###
    # Get cURL command for service with given method and path.
    def api_curl(method, path)
      command = ""

      api_spec = api_specification

      # Get parameters definition.
      parameters = api_parameters(method, path)
      path_parameters = parameters.select { |p| p[:in] == 'path' }
      query_parameters = parameters.select { |p| p[:in] == 'query' }

      # Get the uri parts.
      base_path = api_spec[:basePath].chomp('/').reverse.chomp('/').reverse
      host = api_spec[:host].chomp('/')
      path = path.reverse.chomp('/').reverse

      # Get security token header.
      token = User.current.authentication_token
      token_header = api_spec[:securityDefinitions]['X-User-Access-Token'][:name]

      # Set value of path parameters
      path_parameters.each { |p| path.gsub!("{#{p[:name]}}", @object.send(p[:name])) } if @object

      # Generate data from query_parameters.
      data = api_data(query_parameters)

      # Generate uri and command.
      uri = "#{api_spec[:schemes].first}://#{host}/#{base_path}/#{path}.json"
      command += "curl -X #{method.upcase} \\\n"
      command += "     -H '#{token_header}: #{token}' \\\n"
      command += "     -H 'Content-Type: application/json' \\\n"
      command += "     -d '#{data.to_json}' \\\n" unless data.empty?
      command += "     '#{uri}'\n\n"

      URI.encode(command)
    end

    ###
    # Get parameters for service with given method and path.
    def api_parameters(method, path)
      parameters = api_specification[:paths][path][method][:parameters] || []

      # TODO: Reemplazar las referencias ($ref) por su valor real.

      parameters
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
    def api_default_param_value(type)
      case p[:type]
        when 'integer', 'number', 'real'
          0
        when 'boolean'
          false
        when 'object'
          {}
        when 'array'
          []
        else
          ''
      end
    end

  end
end