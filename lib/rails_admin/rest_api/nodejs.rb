module RailsAdmin
  module RestApi
    ###
    # Generate NodeJS code for api service.
    module Nodejs
      ###
      # Returns NodeJS command for service with given method and path.
      def api_nodejs_code(method, path)
        # Get vars definition.
        data, login = vars(method, path)

        # Generate uri and command.
        command = "TODO: REST-API-NodeJS"

        command
      end
    end
  end
end