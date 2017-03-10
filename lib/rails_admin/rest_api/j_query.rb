module RailsAdmin
  module RestApi
    ###
    # Generate jQuery code for api service.
    module JQuery
      ###
      # Returns jQuery command for service with given method and path.
      def api_jquery_code(method, path)
        # Get vars definition.
        data, uri, vars = api_data('jquery', method, path)

        # Generate uri and command.
        command = ""
        command << api_vars('jquery', vars) + "\n\n" unless vars.empty?
        command << "jQuery.ajax({\n"
        command << "  url: `#{uri}`,\n"
        command << "  method: '#{method.upcase}',\n"
        command << "  dataType: 'json',\n"
        command << "  headers: {\n"
        command << "    'Content-Type': 'application/json',\n"
        command << "    'X-User-Access-Key': user_access_key,\n"
        command << "    'X-User-Access-Token': user_access_token\n"
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