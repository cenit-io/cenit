module RailsAdmin
  module RestApi
    ###
    # Generate Ruby code for api service.
    module Ruby
      ###
      # Returns Ruby command for service with given method and path.
      def api_ruby_code(method, path)
        # Get vars definition.
        data, login = vars(method, path)

        # Generate uri and command.
        command = "TODO: REST-API-RUBY"

        command
      end
    end
  end
end