require 'rails_helper'

RSpec.describe 'Retired OAuth integrations' do
  let(:authorization) { instance_double(Setup::Oauth2Authorization, authorized?: true, access_token: 'existing-token') }

  ['Intuit Reconnect API V1', 'Lazada REST API'].each do |strategy|
    it "rejects a historical #{strategy} refresh configuration before making a request" do
      provider = Setup::Oauth2Provider.new(refresh_token_strategy: strategy)

      expect(provider.refresh_token_strategy_enum).not_to include(strategy)
      expect(Setup::Connection).not_to receive(:get)
      expect(HTTMultiParty).not_to receive(:post)
      expect { provider.refresh_token(authorization) }.to raise_error(ArgumentError, /Unsupported OAuth refresh strategy/)
    end
  end

  it 'does not deserialize a historical Lazada authorization as generic OAuth2' do
    historical_record = {
      '_id' => BSON::ObjectId.new,
      Setup::Oauth2Authorization.discriminator_key => 'Setup::LazadaAuthorization'
    }

    expect {
      Mongoid::Factory.from_db(Setup::Oauth2Authorization, historical_record)
    }.to raise_error(Mongoid::Errors::UnknownModel, /LazadaAuthorization/)
  end

  it 'still uses generic OAuth2 without refreshing a non-expiring token' do
    provider = Setup::Oauth2Provider.new(refresh_token_strategy: 'none')

    expect(provider.refresh_token_strategy_enum).to include('default', 'custom', 'none')
    expect(provider.refresh_token(authorization)).to eq('existing-token')
  end
end
