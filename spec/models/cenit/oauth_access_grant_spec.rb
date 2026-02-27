require 'rails_helper'

RSpec.describe Cenit::OauthAccessGrant do
  describe '#validate_scope' do
    it 'normalizes scope using access_by_ids when valid' do
      grant = described_class.new(scope: 'create read')
      normalized_scope = instance_double('Cenit::OauthScope', valid?: true, to_s: 'read create {"_id":{"$in":["dt-1"]}}')

      allow(grant).to receive(:oauth_scope).and_return(instance_double('Cenit::OauthScope', access_by_ids: normalized_scope))

      expect { grant.validate_scope }.to change { grant.scope }.to('read create {"_id":{"$in":["dt-1"]}}')
      expect(grant.errors).to be_empty
    end

    it 'adds error and aborts callback chain when normalized scope is invalid' do
      grant = described_class.new(scope: 'bad-scope')
      invalid_scope = instance_double('Cenit::OauthScope', valid?: false)
      allow(grant).to receive(:oauth_scope).and_return(instance_double('Cenit::OauthScope', access_by_ids: invalid_scope))

      expect { grant.validate_scope }.to throw_symbol(:abort)
      expect(grant.errors[:scope]).to include('is not valid')
    end
  end

  describe '#check_origin' do
    it 'crosses to owner origin when oauth scope has multi_tenant' do
      grant = described_class.new
      scope = instance_double('Cenit::OauthScope', multi_tenant?: true)

      allow(grant).to receive(:oauth_scope).and_return(scope)
      expect(grant).to receive(:cross).with(:owner)

      grant.check_origin
    end

    it 'crosses to default origin when oauth scope does not have multi_tenant' do
      grant = described_class.new
      scope = instance_double('Cenit::OauthScope', multi_tenant?: false)

      allow(grant).to receive(:oauth_scope).and_return(scope)
      expect(grant).to receive(:cross).with(:default)

      grant.check_origin
    end
  end

  describe '#clear_oauth_tokens' do
    it 'removes access and refresh tokens for current account/application id' do
      account = instance_double('Account')
      app_id = instance_double('Cenit::ApplicationId')
      grant = described_class.new
      allow(grant).to receive(:application_id).and_return(app_id)
      allow(Account).to receive(:current).and_return(account)

      access_relation = instance_double('OauthAccessToken::Relation')
      refresh_relation = instance_double('OauthRefreshToken::Relation')

      expect(Cenit::OauthAccessToken).to receive(:where).with(tenant: account, application_id: app_id).and_return(access_relation)
      expect(access_relation).to receive(:delete_all)

      expect(Cenit::OauthRefreshToken).to receive(:where).with(tenant: account, application_id: app_id).and_return(refresh_relation)
      expect(refresh_relation).to receive(:delete_all)

      grant.clear_oauth_tokens
    end
  end
end
