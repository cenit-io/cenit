module RailsAdmin
  module RestApi
    ###
    # Generate jQuery code for api service.
    module JQuery
      ###
      # Returns jQuery command for service with given method and path.
      def api_jquery_code(method, path)
        # Get vars definition.
        data, login = vars(method, path)

        # Generate uri and command.
        command = ""
        command << "jQuery.ajax({\n"
        command << "  url: '#{api_uri(method, path)}',\n"
        command << "  method: '#{method.upcase}',\n"
        command << "  dataType: 'json',\n"
        command << "  headers: {\n"
        command << "    'Content-Type': 'application/json',\n"
        command << "    'X-User-Access-Key': '#{login ? login.key : '-'}',\n"
        command << "    'X-User-Access-Token': '#{login ? login.token : '-'}'\n"
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