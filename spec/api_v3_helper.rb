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
    end
  end
end