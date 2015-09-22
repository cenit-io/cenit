module RailsAdmin
  module Config
    module Actions

      class Authorize < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::BaseOauthAuthorization
        end


        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do

            cenit_token = CenitToken.create(data: {account_id: Account.current.id, authorization_id: @object.id})

            client = @object.provider.create_http_client(state: cenit_token.token)
            session[:oauth_state] = cenit_token.token

            redirect_to client.auth_code.authorize_url

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