module RailsAdmin
  module RestApi
    ###
    # Generate Python code for api service.
    module Python
      ###
      # Returns Python command for service with given method and path.
      def api_python_code(method, path, with_auth_vars=false)
        # Get vars definition.
        data, uri, vars = api_data('python', method, path, with_auth_vars)
        replace = vars.empty? ? '' : " % (#{vars.keys.join(', ')})"

        # Generate uri and command.
        command = ""
        command << "import json\n" unless data.empty?
        command << "from requests import Request, Session\n"
        command << "\n"
        command << "#{api_vars('python', vars)}\n" unless vars.empty?
        command << "uri = '#{uri}'#{replace}\n"
        command << "options = {\n"
        command << "  'headers': {\n"
        command << "    'Content-Type': 'application/json',\n"
        command << "    'X-Tenant-Access-Key': tenant_access_key,\n"
        command << "    'X-Tenant-Access-Token': tenant_access_token\n"
        command << "  },\n"
        command << "  'data': json.dumps(#{data.to_json})\n" unless data.empty?
        command << "};\n"
        command << "\n"
        command << "session = Session()\n"
        command << "request = Request('#{method.upcase}', uri, **options)\n"
        command << "prepped = request.prepare()\n"
        command << "response = session.send(prepped)\n"
        command << "\n"
        command << "print(response.json())\n"

        command
      end

      ###
      # Returns python inline var access.
      def api_python_inline_var(var)
        "%s"
      end
    end
  end
end