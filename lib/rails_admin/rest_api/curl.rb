module RailsAdmin
  module RestApi
    ###
    # Generate cURL code for api service.
    module Curl
      ###
      # Returns cURL command for service with given method and path.
      def api_curl_code(method, path)
        # Get vars definition.
        data, uri, vars = api_data('curl', method, path)

        # Generate uri and command.
        command = ""
        command << api_vars('curl', vars) + "\n\n" unless vars.empty?
        command << "curl -X #{method.upcase} \\\n"
        command << "     -H 'X-User-Access-Key: ${user_access_key}' \\\n"
        command << "     -H 'X-User-Access-Token: ${user_access_token}' \\\n"
        command << "     -H 'Content-Type: application/json' \\\n"
        command << "     -d '#{data.to_json}' \\\n" unless data.empty?
        command << "     '#{uri}'"

        command
      end

      ###
      # Returns bash vars definition.
      def api_curl_vars(vars)
        vars.map { |k, v| "#{k}='#{vars.is_a?(Hash) ? v : "..."}'" }
      end
    end
  end
end