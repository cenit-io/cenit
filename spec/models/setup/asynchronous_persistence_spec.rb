require 'rails_helper'

RSpec.describe Setup::AsynchronousPersistence do
  describe '#authorize_action' do
    let(:instance) { described_class.new(message: {}) }
    let(:records_model) { instance_double('RecordsModel') }
    let(:target_data_type) { instance_double('TargetDataType', records_model: records_model) }
    let(:ability) { instance_double('Ability') }
    let(:oauth_scope) { nil }

    before do
      allow(instance).to receive(:target_data_type).and_return(target_data_type)
      allow(instance).to receive(:ability).and_return(ability)
      allow(instance).to receive(:oauth_scope).and_return(oauth_scope)
    end

    it 'maps action new to create for ability check' do
      klass = instance_double('AnyModelClass')
      expect(ability).to receive(:can?).with(:create, klass).and_return(true)

      expect(instance.authorize_action(action: 'new', klass: klass)).to be(true)
    end

    it 'returns false when ability denies action' do
      klass = instance_double('AnyModelClass')
      expect(ability).to receive(:can?).with(:update, klass).and_return(false)

      expect(instance.authorize_action(action: 'update', klass: klass)).to be(false)
    end

    it 'returns false when oauth scope denies action even if ability allows it' do
      scope = instance_double('OauthScope')
      allow(instance).to receive(:oauth_scope).and_return(scope)
      klass = instance_double('AnyModelClass')

      expect(ability).to receive(:can?).with(:read, klass).and_return(true)
      expect(scope).to receive(:can?).with(:read, klass).and_return(false)

      expect(instance.authorize_action(action: 'show', klass: klass)).to be(false)
    end
  end
end
