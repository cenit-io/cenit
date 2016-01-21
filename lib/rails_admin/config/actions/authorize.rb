module RailsAdmin
  module Config
    module Actions

      class Authorize < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::BaseOauthAuthorization.class_hierarchy
        end


        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do

            cenit_token = OauthAuthorizationToken.create(authorization: @object, data: {})

            url = @object.authorize_url(cenit_token: cenit_token)

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