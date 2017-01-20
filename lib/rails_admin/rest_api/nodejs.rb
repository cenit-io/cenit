module RailsAdmin
  module RestApi
    ###
    # Generate NodeJS code for api service.
    module Nodejs
      ###
      # Returns NodeJS command for service with given method and path.
      def api_nodejs_code(method, path, with_tokens=true)
        # Get vars definition.
        data, login = vars(method, path)
        key = (with_tokens && login.present?) ? login.key : '{User-Access-Key}'
        token = (with_tokens && login.present?) ? login.token : '{User-Access-Token}'

        # Generate uri and command.
        command = ""
        command << "var request = require('request'),\n"
        command << "    options = {\n"
        command << "      method: '#{method.upcase}',\n"
        command << "      url: '#{api_uri(method, path)}',\n"
        command << "      headers: {\n"
        command << "        'Content-Type': 'application/json',\n"
        command << "        'X-User-Access-Key': '#{key}',\n"
        command << "        'X-User-Access-Token': '#{token}'\n"
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