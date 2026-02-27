require 'rails_helper'

RSpec.describe Cenit::OauthScope do
  describe '#valid?' do
    it 'accepts non-access and access tokens' do
      scope = described_class.new('openid profile email session_access read create')

      expect(scope.valid?).to be(true)
      expect(scope.openid?).to be(true)
      expect(scope.profile?).to be(true)
      expect(scope.email?).to be(true)
      expect(scope.session_access?).to be(true)
      expect(scope.super_method?(:read)).to be(true)
      expect(scope.super_method?(:create)).to be(true)
    end

    it 'rejects malformed criteria payloads' do
      scope = described_class.new('create {"namespace":"Setup","name":{"$in":["Template"]}')

      expect(scope.valid?).to be(false)
      expect(scope.to_s).to eq('<invalid scope>')
    end
  end

  describe '#can?' do
    let(:data_type) { instance_double('Setup::DataType', id: 'dt-template') }
    let(:model) { instance_double('Setup::Template model', data_type: data_type) }

    it 'allows action when granted as super method token' do
      scope = described_class.new('create read')

      expect(scope.can?(:create, model)).to be(true)
      expect(scope.can?(:read, model)).to be(true)
      expect(scope.can?(:delete, model)).to be(false)
    end

    it 'allows action for matching _id criteria' do
      scope = described_class.new('create {"_id":{"$in":["dt-template"]}}')

      expect(scope.can?(:create, model)).to be(true)
    end

    it 'denies action for non-matching _id criteria' do
      scope = described_class.new('create {"_id":{"$in":["dt-other"]}}')

      expect(scope.can?(:create, model)).to be(false)
    end

    it 'resolves non-id criteria through Setup::DataType and authorizes matched model' do
      scope = described_class.new('create {"namespace":"Setup","name":{"$in":["Template","LiquidTemplate"]}}')
      criteria = { 'namespace' => 'Setup', 'name' => { '$in' => ['Template', 'LiquidTemplate'] } }

      allow(Setup::DataType).to receive(:where).with(criteria).and_return([
        instance_double('Setup::DataType', id: 'dt-template')
      ])

      expect(scope.can?(:create, model)).to be(true)
    end

    it 'allows super-method tokens even when model has no data_type, but denies criteria-based actions' do
      scope = described_class.new('create')
      model_without_data_type = instance_double('ModelWithoutDataType')
      allow(model_without_data_type).to receive(:try).with(:data_type).and_return(nil)

      expect(scope.can?(:create, model_without_data_type)).to be(true)
      expect(scope.can?(:digest, model_without_data_type)).to be(false)
    end
  end
end
