module RailsAdmin
  module Config
    module Actions

      class Authorize < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [Setup::BaseOauthAuthorization, Setup::OauthAuthorization, Setup::Oauth2Authorization]
        end


        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do

            cenit_token = CenitToken.new(data: {account_id: Account.current.id, authorization_id: @object.id})
            cenit_token.ensure_token

            url = @object.authorize_url(cenit_token: cenit_token)

            cenit_token.save

            session[:oauth_state] = cenit_token.token

            redirect_to url
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