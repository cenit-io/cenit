module RailsAdmin
  module RestApi
    ###
    # Generate cURL code for api service.
    module Curl
      ###
      # Returns cURL command for service with given method and path.
      def api_curl_code(method, path, with_tokens=true)
        # Get vars definition.
        data, login = vars(method, path)
        key = (with_tokens && login.present?) ? login.key : '{User-Access-Key}'
        token = (with_tokens && login.present?) ? login.token : '{User-Access-Token}'

        # Generate uri and command.
        command = ""
        command << "curl -X #{method.upcase} \\\n"
        command << "     -H 'X-User-Access-Key: #{key}' \\\n"
        command << "     -H 'X-User-Access-Token: #{token}' \\\n"
        command << "     -H 'Content-Type: application/json' \\\n"
        command << "     -d '#{data.to_json}' \\\n" unless data.empty?
        command << "     '#{api_uri(method, path)}'"

        command
      end
    end
  end
end