require 'rails_helper'
require Rails.root.join('lib/cenit/data_action/liquid_mapping').to_s

describe Cenit::DataAction::LiquidMapping do
  let(:code) { '{"external_id":"{{ externalOrderId }}","city":"{{ customer.address.city }}","quantity":{{ items[0].quantity }}}' }
  let(:template) do
    Setup::LiquidTemplate.create!(namespace: 'DataActionLocalPilot', name: SecureRandom.uuid,
      mime_type: 'application/json', code: code)
  end
  let(:data) do
    { 'id' => 'business-id', 'externalOrderId' => 'synthetic-1',
      'customer' => { 'address' => { 'city' => 'Madrid' } }, 'items' => [{ 'quantity' => 2 }] }
  end
  it 'executes a real persisted Cenit template from an explicit document without a record model' do
    mapping = described_class.new(template: template, code_digest: Digest::SHA256.hexdigest(code))
    result = JSON.parse(mapping.call(data))
    expect(result).to eq('external_id' => 'synthetic-1', 'city' => 'Madrid', 'quantity' => 2)
    expect(template.reload.source_data_type).to be_nil
    expect(Cenit::DataAction::Document.new(data).to_hash(include_id: true)['id']).to eq('business-id')
  end
  it 'fails closed when the configured mapping changes' do
    mapping = described_class.new(template: template, code_digest: '0' * 64)
    expect { mapping.call(data) }.to raise_error(Cenit::DataAction::ProtocolError)
  end
  it 'uses private execution storage scoped by the current Cenit account' do
    inbox = Setup::DataActionReceipt.inbox_for_current_account(profile_id: 'synthetic-profile')
    expect(inbox).to be_a(Cenit::DataAction::MongoInbox)
    expect(Setup::DataActionReceipt).not_to respond_to(:build_in_data_type)
  end
  it 'keeps the source document unchanged when a caller edits an exported hash' do
    document = Cenit::DataAction::Document.new(data)
    document.to_hash['customer']['address']['city'] = 'modified'
    expect(document.to_hash['customer']['address']['city']).to eq('Madrid')
    expect(document).not_to respond_to(:save)
    expect(document).not_to respond_to(:where)
  end
end
