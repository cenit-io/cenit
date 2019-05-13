require 'rails_helper'
RSpec.describe Api::V2::ApiController, type: :request do

  describe "POST /api/v2/setup/user" do

    let(:user_email) { 'email@email.com' }
    let(:user_name) { 'Name' }
    let(:usernew) { double('User', :name => "Name") }
    let(:captchatoken) { double('captchatoken', :token => "hARd5P3zCeeuLfysyPvp") }
    
    it "success user creation V2" do
      data = { email: user_email }
      captchatokenE = ""

      # I don't verify if the user exists because I'm considering his absence.

      # Verifying the calls of each external functions
      allow(Devise).to receive(:friendly_token).and_return("eizpd6p3EDxykvh9LxFH")
      allow(User).to receive(:new).and_return(usernew)
      allow(usernew).to receive(:valid?).with(context: :create).and_return(true)
      allow(CaptchaToken).to receive(:create).and_return(captchatoken)
      allow(captchatoken).to receive(:errors).and_return(captchatokenE)
      allow(captchatokenE).to receive(:blank?).and_return(true)

      # User creation request success
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:ok)

      # Verifying the captcha token
      expect(response.body).to eq({token: captchatoken.token}.to_json)
    end

    it "fail email and token missing V2" do
      data = {}
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:bad_request)

      # Verifying the captcha token
      expect(response.body).to eq({token: ['is missing'], email: ['is missing']}.to_json)
      #body_hash = JSON.parse(response.body)
      #expect(body_hash['email']).to eq(["is missing"])
      #expect(body_hash['token']).to eq(["is missing"])
    end

    it "success user creation" do

      data = { email: 'ada@mail.com' }

      # The user does not exists
      user = User.where(email: data[:email]).first
      expect(user).not_to be

      # User creation request success
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:ok)

      # Resolve captcha token
      body_hash = JSON.parse(response.body)
      expect(body_hash).to include('token')
      captcha_token = ::CaptchaToken.where(token: body_hash['token']).first
      expect(captcha_token).to be

      # Confirm captcha token
      post api_v2_setup_user_path, token: captcha_token.token, code: captcha_token.code
      expect(response).to have_http_status(:ok)

      # User creation process success
      body_hash = JSON.parse(response.body)
      expect(body_hash).to include('id', 'number')

      # The created user exists
      user = User.where(email: data[:email]).first
      expect(user).to be
    end

    it "fail email or token missing" do
      data = {}
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:bad_request)

      body_hash = JSON.parse(response.body)
      expect(body_hash['email']).to eq(["is missing"])
      expect(body_hash['token']).to eq(["is missing"])
    end

    it "success user creation with name" do
      data = {
        name: 'Aldo',
        email: 'algo@mail.com'
      }
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:ok)

      body_hash = JSON.parse(response.body)
    end

    it "success user creation with password" do
      data = {
        email: 'bertha@mail.com',
        password: 'test1234'
      }
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:ok)
    end

    it "success user creation with password_confirmation" do
      data = {
        email: 'cat@mail.com',
        password: 'test1234',
        password_confirmation: 'test1234'
      }
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:ok)
    end

    it "fail user creation with wrong password_confirmation" do
      data = {
        email: 'cut@mail.com',
        password: 'test1234',
        password_confirmation: 'test1235'
      }
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['password_confirmation']).to eq(["doesn't match Password"])
    end

    it "success user creation with token" do
      data = { email: 'dan@mail.com' }
      captcha_token = CaptchaToken.create!(email: data[:email], data: data)
      data.merge!(token: captcha_token.token, code: captcha_token.code)

      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:ok)

      body_hash = JSON.parse(response.body)
      expect(body_hash).to include('id', 'number', 'token')
    end

    it "fail in creation with token with email blank" do
      data = {}
      captcha_token = CaptchaToken.create!
      data.merge!(token: captcha_token.token, code: captcha_token.code)

      post api_v2_setup_user_path, data

      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['email']).to eq(["can't be blank"])
    end

    it "fail token that miss info from data" do
      data = { email: 'dom@mail.com' }
      captcha_token = CaptchaToken.create!(
        email: data[:email], data: { email: 'wrong@mail.com' })
      data.merge!(token: captcha_token.token, code: captcha_token.code)

      post api_v2_setup_user_path, data

      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['email']).to eq(["does not match the one previously requested"])
    end

    it "fail token code is not valid" do
      data = { email: 'erik@mail.com' }
      captcha_token = CaptchaToken.create!(email: data[:email], data: data)
      data.merge!(token: captcha_token.token, code: 'not_valid')

      post api_v2_setup_user_path, data

      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['code']).to eq(["is not valid"])
    end

    it "fail token code is missing" do
      data = { email: 'fred@mail.com' }
      captcha_token = CaptchaToken.create!(email: data[:email], data: data)
      data.merge!(token: captcha_token.token, code: nil)

      post api_v2_setup_user_path, data

      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['code']).to eq(["is missing"])
    end

    it "fail token is not valid" do
      data = { email: 'fuzz@mail.com' }
      captcha_token = CaptchaToken.create!(email: data[:email], data: data)
      data.merge!(token: 'not_valid', code: captcha_token.code)

      post api_v2_setup_user_path, data

      expect(response).to have_http_status(:not_acceptable)

      body_hash = JSON.parse(response.body)
      expect(body_hash['token']).to eq(["is not valid"])
    end
  end
end
