require 'rails_helper'

describe Api::V3::ApiController, type: :request do

  describe "POST /api/v3/setup/user" do

    it "successfully creates a user" do

      request_data = { email: 'ada@mail.com' }

      # The user does not exists
      user = User.where(email: request_data[:email]).first
      expect(user).not_to be

      # User creation request success
      post api_v3_setup_user_path, params: request_data, as: :json
      expect(response).to have_http_status(:ok)

      # Resolve captcha token
      response_data = JSON.parse(response.body)
      expect(response_data).to include('token')
      captcha_token = ::CaptchaToken.where(token: response_data['token']).first
      expect(captcha_token).to be

      # Confirm captcha token
      post api_v3_setup_user_path, params: {
        token: captcha_token.token,
        code: captcha_token.code
      }, as: :json
      expect(response).to have_http_status(:ok)

      # User creation process success
      response_data = JSON.parse(response.body)
      expect(response_data).to include('id', 'number')

      # The created user exists
      user = User.find(response_data['id'])
      expect(user).to be
      expect(user.email).to eq(request_data[:email])
    end

    it "fails when the email or token are missing" do
      request_data = {}
      post api_v3_setup_user_path, params: request_data, as: :json
      expect(response).to have_http_status(:bad_request)

      response_data = JSON.parse(response.body)
      expect(response_data['email']).to eq(['is missing'])
      expect(response_data['token']).to eq(['is missing'])
    end

    it "successfully creates a user with name" do
      request_data = {
        name: 'Aldo',
        email: 'aldo@mail.com'
      }
      user = create_user(request_data)
      expect(user.email).to eq(request_data[:email])
      expect(user.name).to eq(request_data[:name])
    end

    it "successfully creates a user with password" do
      request_data = {
        email: 'bertha@mail.com',
        password: 'test1234'
      }
      user = create_user(request_data)
      expect(user.email).to eq(request_data[:email])
      expect(user.encrypted_password).to eq(request_data[:password])
    end


    it "successfully creates a user with a valid token" do
      user_data = { email: 'dan@mail.com' }
      captcha_token = CaptchaToken.create!(email: user_data[:email], data: user_data)

      post api_v3_setup_user_path, params: {
        token: captcha_token.token,
        code: captcha_token.code
      }, as: :json
      expect(response).to have_http_status(:ok)

      response_data = JSON.parse(response.body)
      user = User.find(response_data['id'])
      expect(user.email).to eq(user_data[:email])
    end

    it "fails on user creation request with a missing email token" do
      captcha_token = CaptchaToken.create!(data: {}) # no email

      post api_v3_setup_user_path, params: {
        token: captcha_token.token,
        code: captcha_token.code
      }, as: :json

      expect(response).to have_http_status(:not_acceptable)

      response_data = JSON.parse(response.body)
      expect(response_data['email']).to eq(["can't be blank"])
    end

    it "fails on user creation request with a mismatching token emails" do
      email = 'dom@mail.com'
      captcha_token = CaptchaToken.create!(
        email: email,
        data: { email: 'wrong@mail.com' }
      )

      post api_v3_setup_user_path, params: {
        email: email,
        token: captcha_token.token,
        code: captcha_token.code
      }, as: :json

      expect(response).to have_http_status(:not_acceptable)

      response_data = JSON.parse(response.body)
      expect(response_data['email']).to eq(["does not match the one previously requested"])
    end

    it "fails on user creation request with an invalid code" do
      captcha_token = CaptchaToken.create!(data: { email: 'erik@mail.com' })

      post api_v3_setup_user_path, params: {
        token: captcha_token.token,
        code: 'not valid'
      }, as: :json

      expect(response).to have_http_status(:not_acceptable)

      response_data = JSON.parse(response.body)
      expect(response_data['code']).to eq(['is not valid'])
    end

    it "fails on user creation request if code is missing" do
      captcha_token = CaptchaToken.create!(data: { email: 'fred@mail.com' })

      post api_v3_setup_user_path, params: {
        token: captcha_token.token # no code
      }, as: :json

      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['code']).to eq(['is missing'])
    end

    it "fails on user creation request with an invalid token" do
      captcha_token = CaptchaToken.create!(data: {email: 'fuzz@mail.com'})

      post api_v3_setup_user_path, params: {
        token: 'not valid',
        code: captcha_token.code
      }, as: :json

      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['token']).to eq(["is not valid"])
    end
  end
end
