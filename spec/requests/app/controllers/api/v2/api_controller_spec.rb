require 'rails_helper'
RSpec.describe Api::V2::ApiController, type: :request do
  describe "POST /api/v2/setup/user" do
    it "success user creation" do
      data = { email: 'ada@mail.com' }
      post api_v2_setup_user_path, data
      expect(response).to have_http_status(:ok)

      body_hash = JSON.parse(response.body)
      expect(body_hash).to include('token')
      expect(body_hash).not_to include('id', 'number')
    end

    it "fail email or token missing" do
      data = { }
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
        email: data[:email], data: { email: 'wrong@mail.com'})
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
