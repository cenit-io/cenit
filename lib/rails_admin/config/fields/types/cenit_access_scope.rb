module RailsAdmin
  module Config
    module Fields
      module Types
        class CenitAccessScope < RailsAdmin::Config::Fields::Types::CenitOauthScope

          register_instance_option :access_tokens do
            Cenit::OauthScope::ACCESS_TOKENS
          end

          register_instance_option :cenit_basic_scopes do
            Cenit::OauthScope::ACCESS_TOKENS
          end
        end
      end
    end
  end
end
