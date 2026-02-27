require 'rails_helper'

RSpec.describe Cenit::OauthAccessToken do
  DummyUser = Struct.new(:id, :email, :name, :given_name, :family_name, :middle_name, :picture_url, keyword_init: true) do
    def confirmed?
      true
    end
  end

  describe '.for' do
    let(:tenant_model) { instance_double('TenantModel', current: tenant) }
    let(:tenant) { instance_double('Tenant') }
    let(:app_id) { instance_double('AppId', identifier: 'app-1', trusted?: true) }
    let(:user) do
      DummyUser.new(
        id: 'user-1',
        email: 'support@cenit.io',
        name: 'Support Cenit',
        given_name: 'Support',
        family_name: 'Cenit',
        middle_name: 'Team',
        picture_url: 'http://example.test/pic.png'
      )
    end
    let(:token_time) { Time.at(1_772_218_569) }
    let(:token) do
      instance_double(
        'OauthAccessToken',
        token: 'access-token',
        token_type: :Bearer,
        created_at: token_time,
        token_span: 3600
      )
    end

    before do
      allow(Cenit::MultiTenancy).to receive(:tenant_model).and_return(tenant_model)
      allow(Cenit::MultiTenancy).to receive(:user_model).and_return(nil)
      allow(tenant).to receive(:switch).and_yield
      allow(Cenit).to receive(:homepage).and_return('http://example.test')
    end

    it 'merges scope into access grant and uses session token class when session_access is present' do
      access_grant = Struct.new(:scope) do
        def save
          true
        end
      end.new('read')

      allow(Cenit::OauthAccessGrant).to receive(:where)
        .with(application_id: app_id)
        .and_return(instance_double('Relation', first: access_grant))

      refresh_token = instance_double('RefreshToken', token: 'refresh-token')
      allow(Cenit::OauthRefreshToken).to receive(:where)
        .with(tenant: tenant, application_id: app_id, user_id: user.id)
        .and_return(instance_double('RefreshRelation', first: refresh_token))

      expect(Cenit::OauthSessionAccessToken).to receive(:create)
        .with(hash_including(tenant: tenant, application_id: app_id, user_id: user.id, token_span: 120, data: { note: 'test-note' }))
        .and_return(token)

      response = described_class.for(app_id, 'session_access offline_access create', user, tenant: tenant, token_span: 120, note: 'test-note')

      merged_scope = Cenit::OauthScope.new(access_grant.scope)
      expect(merged_scope.super_method?(:read)).to be(true)
      expect(merged_scope.super_method?(:create)).to be(true)
      expect(merged_scope.session_access?).to be(true)
      expect(merged_scope.offline_access?).to be(true)

      expect(response[:access_token]).to eq('access-token')
      expect(response[:refresh_token]).to eq('refresh-token')
      expect(response[:expires_in]).to eq(3600)
    end

    it 'creates refresh token when offline_access scope is requested and none exists' do
      access_grant = Struct.new(:scope) do
        def save
          true
        end
      end.new('')

      allow(Cenit::OauthAccessGrant).to receive(:where)
        .with(application_id: app_id)
        .and_return(instance_double('Relation', first: access_grant))

      allow(described_class).to receive(:create).and_return(token)

      allow(Cenit::OauthRefreshToken).to receive(:where)
        .with(tenant: tenant, application_id: app_id, user_id: user.id)
        .and_return(instance_double('RefreshRelation', first: nil))

      created_refresh = instance_double('RefreshToken', token: 'created-refresh-token')
      expect(Cenit::OauthRefreshToken).to receive(:create)
        .with(tenant: tenant, application_id: app_id, user_id: user.id)
        .and_return(created_refresh)

      response = described_class.for(app_id, 'offline_access read', user, tenant: tenant)

      expect(response[:refresh_token]).to eq('created-refresh-token')
      expect(response[:access_token]).to eq('access-token')
    end

    it 'adds id_token payload for openid scopes' do
      access_grant = Struct.new(:scope) do
        def save
          true
        end
      end.new('')

      allow(Cenit::OauthAccessGrant).to receive(:where)
        .with(application_id: app_id)
        .and_return(instance_double('Relation', first: access_grant))

      allow(described_class).to receive(:create).and_return(token)
      allow(JWT).to receive(:encode).and_return('jwt-id-token')

      response = described_class.for(app_id, 'openid email profile read', user, tenant: tenant)

      expect(response[:id_token]).to eq('jwt-id-token')
      expect(JWT).to have_received(:encode).with(
        hash_including(
          iss: 'http://example.test',
          sub: user.id.to_s,
          aud: app_id.identifier,
          iat: token_time.to_i,
          exp: token_time.to_i + 3600,
          email: user.email,
          name: user.name,
          given_name: user.given_name,
          family_name: user.family_name,
          middle_name: user.middle_name,
          picture: user.picture_url
        ),
        nil,
        'none'
      )
    end
  end
end
