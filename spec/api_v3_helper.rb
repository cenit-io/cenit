module Api::V3::ApiController::Test
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