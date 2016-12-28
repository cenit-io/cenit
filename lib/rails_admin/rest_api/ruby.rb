module RailsAdmin
  module RestApi
    ###
    # Generate Ruby code for api service.
    module Ruby
      ###
      # Returns Ruby command for service with given method and path.
      def api_ruby_code(method, path)
        # Get vars definition.
        data, login = vars(method, path)
        a = {
          :h => {
            :a => 1
          }
        }
        # Generate uri and command.
        command = "require 'rest-client'\n"
        command << "require 'json'\n"
        command << "\n"
        command << "uri = '#{api_uri(method, path)}'\n"
        command << "\n"
        command << "response = RestClient::Request.execute(\n"
        command << "  :url => uri,\n"
        command << "  :method => '#{method.upcase}',\n"
        command << "  :headers => {\n"
        command << "    'Content-Type' => 'application/json',\n"
        command << "    'X-User-Access-Key' => 'A480067472',\n"
        command << "    'X-User-Access-Token' => 'oj_kJJ5ochVyDP3Q82CM',\n"
        command << "    'params' => #{data.to_json}\n" unless data.empty?
        command << "  }\n"
        command << ")\n"
        command << "\n"
        command << "puts JSON.parse(response.body)\n"

        command
      end
    end
  end
end