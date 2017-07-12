module RailsAdmin
  module RestApi
    ###
    # Generate Ruby code for api service.
    module Ruby
      ###
      # Returns Ruby command for service with given method and path.
      def api_ruby_code(method, path, with_auth_vars=false)
        # Get vars definition.
        data, uri, vars = api_data('ruby', method, path, with_auth_vars)

        # Generate uri and command.
        command = ""
        command << "require 'rest-client'\n"
        command << "require 'json'\n"
        command << "\n"
        command << "#{api_vars('ruby', vars)}\n\n" unless vars.empty?
        command << "response = RestClient::Request.execute(\n"
        command << "  :url => \"#{uri}\",\n"
        command << "  :method => '#{method.upcase}',\n"
        command << "  :payload => '#{data.to_json}',\n" unless data.empty?
        command << "  :headers => {\n"
        command << "    'Content-Type' => 'application/json',\n"
        command << "    'X-Tenant-Access-Key' => tenant_access_key,\n"
        command << "    'X-Tenant-Access-Token' => tenant_access_token\n"
        command << "  }\n"
        command << ")\n"
        command << "\n"
        command << "puts JSON.parse(response.body)\n"

        command
      end

      ###
      # Returns ruby inline var access.
      def api_ruby_inline_var(var)
        "\#{#{var}}"
      end
    end
  end
end
