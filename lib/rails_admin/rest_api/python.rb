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
        command = "TODO: REST-API-PYTHON"

        command
      end
    end
  end
end