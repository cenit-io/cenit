require 'rails_helper'

RSpec.describe OauthController, type: :request do
  describe 'GET /oauth/authorize' do
    it 'creates consent token payload for a valid authorize request' do
      user = User.current || User.first
      login_as(user, scope: :user)

      app = double('Setup::Application', configuration: double('AppConfig', logo: '/oauth-logo.png'))
      app_id = instance_double(
        'Cenit::ApplicationId',
        tenant: Account.current,
        registered?: false,
        redirect_uris: ['http://localhost:3002/callback'],
        app: app,
        name: 'E2E App'
      )
      app_relation = instance_double('ApplicationIdRelation', first: app_id)
      allow(Cenit::ApplicationId).to receive(:where).with(identifier: 'client-1').and_return(app_relation)
      allow(Cenit::OauthAccessGrant).to receive(:where).with(application_id: app_id).and_return(double(first: nil))

      token = double('Cenit::Token', token: 'consent-token')
      expect(Cenit::Token).to receive(:create).with(
        data: hash_including(
          scope: 'read',
          redirect_uri: 'http://localhost:3002/callback',
          state: 'state-1'
        )
      ).and_return(token)

      get '/oauth/authorize', params: {
        client_id: 'client-1',
        response_type: 'code',
        redirect_uri: 'http://localhost:3002/callback',
        scope: 'read',
        state: 'state-1'
      }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /oauth/authorize' do
    it 'redirects with code and state when consent is allowed' do
      user = User.current || User.first
      login_as(user, scope: :user)
      User.current = user

      consent_token = double(
        'Cenit::Token',
        data: {
          'scope' => 'read',
          'redirect_uri' => 'http://localhost:3002/callback',
          'state' => 'state-1'
        },
        destroy: true
      )
      token_relation = instance_double('TokenRelation', first: consent_token)
      allow(Cenit::Token).to receive(:where).with(token: 'consent-token').and_return(token_relation)

      code_token = instance_double('Cenit::OauthCodeToken', token: 'auth-code-1')
      expect(Cenit::OauthCodeToken).to receive(:create).with(scope: 'read', user_id: user.id).and_return(code_token)

      post '/oauth/authorize', params: {
        token: 'consent-token',
        allow: '1'
      }

      expect(response).to have_http_status(:redirect)
      location = response.headers['Location']
      expect(location).to include('http://localhost:3002/callback')
      expect(location).to include('code=auth-code-1')
      expect(location).to include('state=state-1')
    end

    it 'redirects with access denied when consent is denied' do
      user = User.current || User.first
      login_as(user, scope: :user)
      User.current = user

      consent_token = double(
        'Cenit::Token',
        data: {
          'scope' => 'read',
          'redirect_uri' => 'http://localhost:3002/callback',
          'state' => 'state-1'
        },
        destroy: true
      )
      token_relation = instance_double('TokenRelation', first: consent_token)
      allow(Cenit::Token).to receive(:where).with(token: 'consent-token').and_return(token_relation)
      expect(Cenit::OauthCodeToken).not_to receive(:create)

      post '/oauth/authorize', params: {
        token: 'consent-token',
        deny: '1'
      }

      expect(response).to have_http_status(:redirect)
      location = response.headers['Location']
      expect(location).to include('http://localhost:3002/callback')
      expect(location).to include('error=Access+denied')
      expect(location).to include('state=state-1')
    end

    it 'returns bad_request when consent token is missing' do
      user = User.current || User.first
      login_as(user, scope: :user)

      post '/oauth/authorize', params: { allow: '1' }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include('Consent time out')
    end

    it 'returns bad_request when consent token is invalid' do
      user = User.current || User.first
      login_as(user, scope: :user)

      token_relation = instance_double('TokenRelation', first: nil)
      allow(Cenit::Token).to receive(:where).with(token: 'missing-token').and_return(token_relation)

      post '/oauth/authorize', params: {
        token: 'missing-token',
        allow: '1'
      }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include('Consent time out')
    end
  end

  describe 'POST /oauth/token' do
    it 'returns bad_request for invalid grant_type' do
      post '/oauth/token', params: { grant_type: 'unknown' }

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to include('Invalid grant_type parameter.')
    end

    it 'returns bad_request when authorization_code is missing code' do
      post '/oauth/token', params: { grant_type: 'authorization_code' }

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to include('Code missing.')
      expect(body['error']).to include('Invalid authorization code.')
    end

    it 'returns bad_request when refresh_token is invalid' do
      relation = instance_double('OauthRefreshTokenRelation', first: nil)
      allow(Cenit::OauthRefreshToken).to receive(:where).with(token: 'bad-refresh').and_return(relation)

      post '/oauth/token', params: { grant_type: 'refresh_token', refresh_token: 'bad-refresh' }

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to include('Invalid refresh token.')
    end

    it 'returns bad_request for invalid client credentials' do
      code_token = instance_double(
        'OauthCodeToken',
        set_current_tenant!: true,
        destroy: true,
        long_term?: false,
        scope: 'read',
        user_id: 'u-1',
        tenant: 't-1'
      )
      code_relation = instance_double('OauthCodeTokenRelation', first: code_token)
      allow(Cenit::OauthCodeToken).to receive(:where).with(token: 'code-1').and_return(code_relation)

      app = instance_double('Setup::Application', secret_token: 'expected-secret')
      app_id = instance_double('Cenit::ApplicationId', app: app, redirect_uris: ['http://localhost:3002'])
      app_relation = instance_double('ApplicationIdRelation', first: app_id)
      allow(Cenit::ApplicationId).to receive(:where).with(identifier: 'client-1').and_return(app_relation)

      post '/oauth/token', params: {
        grant_type: 'authorization_code',
        code: 'code-1',
        client_id: 'client-1',
        client_secret: 'wrong-secret',
        redirect_uri: 'http://localhost:3002'
      }

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to include('Invalid client credentials.')
    end

    it 'returns access token payload for valid authorization_code exchange' do
      code_token = instance_double(
        'OauthCodeToken',
        set_current_tenant!: true,
        destroy: true,
        long_term?: false,
        scope: 'read',
        user_id: 'u-1',
        tenant: 't-1'
      )
      code_relation = instance_double('OauthCodeTokenRelation', first: code_token)
      allow(Cenit::OauthCodeToken).to receive(:where).with(token: 'code-1').and_return(code_relation)

      app = instance_double('Setup::Application', secret_token: 'expected-secret')
      app_id = instance_double('Cenit::ApplicationId', app: app, redirect_uris: ['http://localhost:3002'])
      app_relation = instance_double('ApplicationIdRelation', first: app_id)
      allow(Cenit::ApplicationId).to receive(:where).with(identifier: 'client-1').and_return(app_relation)

      allow(Cenit::OauthAccessToken).to receive(:for)
        .with(app_id, 'read', 'u-1', tenant: 't-1')
        .and_return(
          access_token: 'access-1',
          token_type: 'Bearer',
          created_at: 1_700_000_000,
          expires_in: 3600
        )

      post '/oauth/token', params: {
        grant_type: 'authorization_code',
        code: 'code-1',
        client_id: 'client-1',
        client_secret: 'expected-secret',
        redirect_uri: 'http://localhost:3002'
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['access_token']).to eq('access-1')
      expect(body['token_type']).to eq('Bearer')
      expect(body['expires_in']).to eq(3600)
    end
  end
end
