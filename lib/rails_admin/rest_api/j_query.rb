module RailsAdmin
  module RestApi
    ###
    # Generate jQuery code for api service.
    module JQuery
      ###
      # Returns jQuery command for service with given method and path.
      def api_jquery_code(method, path, with_tokens=true)
        # Get vars definition.
        data, login = vars(method, path)
        key = (with_tokens && login.present?) ? login.key : '{User-Access-Key}'
        token = (with_tokens && login.present?) ? login.token : '{User-Access-Token}'

        # Generate uri and command.
        command = ""
        command << "jQuery.ajax({\n"
        command << "  url: '#{api_uri(method, path)}',\n"
        command << "  method: '#{method.upcase}',\n"
        command << "  dataType: 'json',\n"
        command << "  headers: {\n"
        command << "    'Content-Type': 'application/json',\n"
        command << "    'X-User-Access-Key': '#{key}',\n"
        command << "    'X-User-Access-Token': '#{token}'\n"
        command << "  },\n"
        command << "  data: #{data.to_json}\n" unless data.empty?
        command << "  success: function(data, textStatus, jqXHR) {\n"
        command << "    console.log(data);\n"
        command << "  }\n"
        command << "});\n"

        command
      end
    end
  end
end