module RailsAdmin
  module RestApi
    ###
    # Generate cURL code for api service.
    module Curl
      ###
      # Returns cURL command for service with given method and path.
      def api_curl_code(method, path)
        # Get vars definition.
        data, login = vars(method, path)

        # Generate uri and command.
        command = "curl -X #{method.upcase} \\\n"
        command << "     -H 'X-User-Access-Key: #{login ? login.key : '-'}' \\\n"
        command << "     -H 'X-User-Access-Token: #{login ? login.token : '-'}' \\\n"
        command << "     -H 'Content-Type: application/json' \\\n"
        command << "     -d '#{data.to_json}' \\\n" unless data.empty?
        command << "     '#{api_uri(method, path)}'"

        command
      end
    end
  end
end