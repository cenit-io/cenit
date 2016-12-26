module RailsAdmin
  module RestApi
    ###
    # Generate Python code for api service.
    module Python
      ###
      # Returns Python command for service with given method and path.
      def api_python_code(method, path)
        # Get vars definition.
        data, login = vars(method, path)

        # Generate uri and command.
        command =  ""
        command <<  "import json\n" unless data.empty?
        command <<  "from requests import Request, Session\n"
        command <<  "\n"
        command <<  "uri = '#{api_uri(method, path)}'\n"
        command << "options = {\n"
        command << "  'headers': {\n"
        command << "    'Content-Type': 'application/json',\n"
        command << "    'X-User-Access-Key': '#{login ? login.key : '-'}',\n"
        command << "    'X-User-Access-Token': '#{login ? login.token : '-'}'\n"
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
    end
  end
end