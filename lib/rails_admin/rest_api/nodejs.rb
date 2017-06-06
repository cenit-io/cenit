module RailsAdmin
  module RestApi
    ###
    # Generate NodeJS code for api service.
    module Nodejs
      ###
      # Returns NodeJS command for service with given method and path.
      def api_nodejs_code(method, path, with_auth_vars=false)
        # Get vars definition.
        data, uri, vars = api_data('nodejs', method, path, with_auth_vars)
        method = method.to_s.upcase

        # Generate uri and command.
        command = ""
        command << "var request = require('request'),\n"
        command << "    #{api_vars('nodejs', vars).gsub(/\n/, ",\n    ")},\n" unless vars.empty?
        command << "    options = {\n"
        command << "      method: '#{method}',\n"
        command << "      url: '#{uri}',\n"
        command << "      headers: {\n"
        command << "        'Content-Type': 'application/json',\n"
        command << "        'X-Tenant-Access-Key': tenant_access_key,\n"
        command << "        'X-Tenant-Access-Token': tenant_access_token\n"
        command << "      },\n"
        command << "      json: true,\n"
        command << "      #{(method == 'GET') ? 'qs' : 'body'}: #{data.to_json}\n" unless data.empty?
        command << "    };\n"
        command << "\n"
        command << "request(options, function (error, response, data) {\n"
        command << "  if (error) throw error;\n"
        command << "\n"
        command << "  console.log(data);\n"
        command << "});\n"

        command
      end
    end
  end
end