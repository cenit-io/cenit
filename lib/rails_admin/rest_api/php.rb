module RailsAdmin
  module RestApi
    ###
    # Generate PHP code for api service.
    module Php
      ###
      # Returns PHP command for service with given method and path.
      def api_php_code(method, path, with_auth_vars=false)
        # Get vars definition.
        data, uri, vars = api_data('php', method, path, with_auth_vars)

        # Generate uri and command.
        command = ""
        command << "#{api_vars('php', vars)}\n" unless vars.empty?
        command << "$uri = \"#{uri}\";\n"
        command << "$headers = array(\n"
        command << "  \"Content-Type: application/json\",\n"
        command << "  \"X-Tenant-Access-Key: ${tenant_access_key}\",\n"
        command << "  \"X-Tenant-Access-Token: ${tenant_access_token}\"\n"
        command << ");\n"
        command << "$options = array(\n"
        command << "  'http' => array(\n"
        command << "    'header'  => implode($headers, \"\\r\\n\"),\n"
        command << "    'method'  => '#{method.upcase}',\n"
        command << "    'content' => '#{data.to_json}'\n" unless data.empty?
        command << "  )\n"
        command << ");\n"
        command << "\n"
        command << "$context  = stream_context_create($options);\n"
        command << "$response = file_get_contents($uri, false, $context);\n"
        command << "\n"
        command << "print_r(json_decode($response, true));"

        command
      end

      ###
      # Returns php vars definition.
      def api_php_vars(vars)
        vars.map { |k, v| "$#{k} = '#{vars.is_a?(Hash) ? v : "..."}';" }
      end

    end
  end
end