module RailsAdmin
  module RestApi
    ###
    # Generate Ruby code for api service.
    module Ruby
      ###
      # Returns Ruby command for service with given method and path.
      def api_ruby_code(method, path, with_tokens=true)
        # Get vars definition.
        data, login = vars(method, path)
        key = (with_tokens && login.present?) ? login.key : '{User-Access-Key}'
        token = (with_tokens && login.present?) ? login.token : '{User-Access-Token}'

        # Generate uri and command.
        command = ""
        command << "require 'rest-client'\n"
        command << "require 'json'\n"
        command << "\n"
        command << "response = RestClient::Request.execute(\n"
        command << "  :url => '#{api_uri(method, path)}',\n"
        command << "  :method => '#{method.upcase}',\n"
        command << "  :headers => {\n"
        command << "    'Content-Type' => 'application/json',\n"
        command << "    'X-User-Access-Key' => '#{key}',\n"
        command << "    'X-User-Access-Token' => '#{token}',\n"
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