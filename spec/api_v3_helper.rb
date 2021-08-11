module Api
  module V3
    module Test

      DEFAULT_USER_EMAIL = ENV['DEFAULT_USER_EMAIL'] || 'support@cenit.io'

      def default_user
        ::User.where(email: DEFAULT_USER_EMAIL).first
      end

      def create_user(data)
        # Request user creation
        post api_v3_setup_user_path, params: data, as: :json

        # Resolve captcha token
        response_data = JSON.parse(response.body)
        captcha_token = ::CaptchaToken.where(token: response_data['token']).first

        # Confirm captcha token
        post api_v3_setup_user_path, params: {
            token: captcha_token.token,
            code: captcha_token.code
        }, as: :json

        # Resolve user
        response_data = JSON.parse(response.body)
        User.find(response_data['id'])
      end

      def json_response
        @json_response ||= JSON.parse(response.body, symbolize_names: true)
      end

      def header_token_authorization
        @header_token_authorization ||= create_acces_read_app
      end

      def headers_token_authorization
        @header_token_authorization_create ||= create_acces_app
      end

      def create_acces_app
        search_app = ::Setup::Application.where(namespace: 'Test', name: 'ApiV3').first
        app = search_app ? search_app : ::Setup::Application.create!(namespace: 'Test', name: 'ApiV3')

        access_grant_read = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: 'read'
        )

        access_grant_create = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: 'create'
        )

        access_grant_delete = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: 'delete'
        )

        access_grant_update = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: 'update'
        )

        access_grant_digest = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: 'digest'
        )

        test_user = ::User.current
        access_read = ::Cenit::OauthAccessToken.for(
            app.application_id,
            access_grant_read.scope,
            test_user
        )

        access_create = ::Cenit::OauthAccessToken.for(
            app.application_id,
            access_grant_create.scope,
            test_user
        )

        access_delete = ::Cenit::OauthAccessToken.for(
            app.application_id,
            access_grant_delete.scope,
            test_user
        )

        access_update = ::Cenit::OauthAccessToken.for(
            app.application_id,
            access_grant_update.scope,
            test_user
        )

        access_digest = ::Cenit::OauthAccessToken.for(
            app.application_id,
            access_grant_digest.scope,
            test_user
        )

        return {
            header_token_read: {
                Authorization: "Bearer #{access_read[:access_token]}"
            },
            header_token_create: {
                Authorization: "Bearer #{access_create[:access_token]}"
            },
            header_token_delete: {
                Authorization: "Bearer #{access_delete[:access_token]}"
            },
            header_token_update: {
                Authorization: "Bearer #{access_update[:access_token]}"
            },
            header_token_digest: {
                Authorization: "Bearer #{access_digest[:access_token]}"
            }
        }
      end

      def create_acces_read_app
        search_app = ::Setup::Application.where(namespace: 'Testing', name: 'ApiV3Post').first
        app = search_app ? search_app : ::Setup::Application.create!(namespace: 'Testing', name: 'ApiV3Post')


        access_grant = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: 'read'
        )

        test_user = ::User.current
        access = ::Cenit::OauthAccessToken.for(
            app.application_id,
            access_grant.scope,
            test_user
        )

        return header_token = {
            Authorization: "Bearer #{access[:access_token]}"
        }
      end

    end
  end
end