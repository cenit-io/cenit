module RailsAdmin
  module RestApi
    ###
    # Generate jQuery code for api service.
    module JQuery
      ###
      # Returns jQuery command for service with given method and path.
      def api_jquery_code(method, path, with_auth_vars=false)
        # Get vars definition.
        data, uri, vars = api_data('jquery', method, path, with_auth_vars)
        method = method.to_s.upcase

        # Generate uri and command.
        command = ""
        command << "var #{api_vars('jquery', vars).gsub(/\n/, ",\n    ")};\n\n" unless vars.empty?
        command << "jQuery.ajax({\n"
        command << "  url: '#{uri}',\n"
        command << "  method: '#{method}',\n"
        command << "  dataType: 'json',\n"
        command << "  crossOrigin: true,\n"
        command << "  headers: {\n"
        command << "    'Content-Type': 'application/json',\n"
        command << "    'X-Tenant-Access-Key': tenant_access_key,\n"
        command << "    'X-Tenant-Access-Token': tenant_access_token\n"
        command << "  },\n"
        command << "  data: #{data.to_json},\n" if data.any? && method == 'GET'
        command << "  data: JSON.stringify(#{data.to_json}),\n" if data.any? && method != 'GET'
        command << "  success: function(data, textStatus, jqXHR) {\n"
        command << "    console.log(data);\n"
        command << "  }\n"
        command << "});\n"

        command
      end
    end
  end
end