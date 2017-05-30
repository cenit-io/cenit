module RailsAdmin
  module RestApi
    ###
    # Generate NodeJS code for api service.
    module Nodejs
      ###
      # Returns NodeJS command for service with given method and path.
      def api_nodejs_code(method, path)
        # Get vars definition.
        data, uri, vars = api_data('nodejs', method, path)

        # Generate uri and command.
        command = ""
        command << "var request = require('request'),\n"
        command << "    #{api_vars('nodejs', vars).gsub("\n", "    \n")}\n" unless vars.empty?
        command << "    options = {\n"
        command << "      method: '#{method.upcase}',\n"
        command << "      url: '#{uri}',\n"
        command << "      headers: {\n"
        command << "        'Content-Type': 'application/json',\n"
        command << "        'X-User-Access-Key': user_access_key,\n"
        command << "        'X-User-Access-Token': user_access_token\n"
        command << "      },\n"
        command << "      form: #{data.to_json}\n" unless data.empty?
        command << "    };\n"
        command << "\n"
        command << "request(options, function (error, response, body) {\n"
        command << "  if (error) throw error;\n"
        command << "\n"
        command << "  console.log(JSON.parse(body));\n"
        command << "});\n"

        command
      end
    end
  end
end