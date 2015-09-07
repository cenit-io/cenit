module RailsAdmin
  module Config
    module Actions

      class Authorize < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Oauth2Authorization
        end


        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do

            client = OAuth2::Client.new(@object.client.identifier,
                                        @object.client.secret,
                                        authorize_url: @object.provider.authorization_endpoint)

            if http_proxy = Cenit.http_proxy
              client.connection.proxy(http_proxy)
            end
            cenit_token = CenitToken.create(data: {account_id: Account.current.id, authorization_id: @object.id})
            options =
              {
                redirect_uri: "#{Cenit.oauth2_callback_site}/oauth2/callback",
                state: cenit_token.token,
                scope: @object.scopes.collect { |scope| scope.name }.join(' ')
              }
            @object.provider.parameters.each { |parameter| options[parameter.key.to_sym] = parameter.value }

            redirect_to client.auth_code.authorize_url(options)

          end
        end

        register_instance_option :link_icon do
          'icon-check'
        end

        register_instance_option :pjax? do
          false
        end
      end

    end
  end
end