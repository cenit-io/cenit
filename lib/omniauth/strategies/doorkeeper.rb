module OmniAuth
  module Strategies
    class Doorkeeper < OmniAuth::Strategies::OAuth2
      option :name, :doorkeeper

      option :client_options, {
        :site => "http://localhost:3000",
        :authorize_path => "/oauth/authorize"
      }

      uid do
        raw_info["id"]
      end

      info do
        {
          :email => raw_info["email"]
        }
      end

      def raw_info
        puts "^^^^^^^^^^^^^^^^^^^^^ access_token #{access_token.inspect}"
        @raw_info ||= access_token.get('/api/v1/me.json').parsed
      end
    end
  end
end