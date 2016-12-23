module RailsAdmin
  module RestApi
    ###
    # Generate JavaScript code for api service.
    module JavaScript
      ###
      # Returns JavaScript command for service with given method and path.
      def api_javascript_code(method, path)
        # Get vars definition.
        data, login = vars(method, path)

        # Generate uri and command.
        command = "TODO: REST-API-JAVASCRIPT"

        command
      end
    end
  end
end