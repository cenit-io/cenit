module RailsAdmin
  module Config
    module Actions

      class Authorize < RailsAdmin::Config::Actions::Base

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
                                        site: @object.provider.authorization_endpoint)

            redirect_to client.auth_code.authorize_url(redirect_uri: "#{Cenit.oauth2_callback_site}/oauth2/callback",
                                                       state: Account.current.id.to_s + ' ' + @object.id.to_s)

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