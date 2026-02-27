require 'rails_helper'

RSpec.describe Cenit::Application do
  describe '.install_build_in_apps' do
    let(:app_module) { instance_double('BuildInAppModule', to_s: 'Cenit::OauthApp') }

    before do
      allow(Cenit::BuildInApps).to receive(:apps_modules).and_return([app_module])
    end

    it 'skips failing app modules in test boot instead of aborting initialization' do
      allow(Cenit::BuildInApp).to receive(:find_or_create_by).and_raise(SystemStackError, 'stack level too deep')

      result = nil
      expect { result = described_class.install_build_in_apps }.not_to raise_error
      expect(result).to eq([])
    end

    it 're-raises outside test environment' do
      allow(Cenit::BuildInApp).to receive(:find_or_create_by).and_raise(SystemStackError, 'stack level too deep')
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      expect { described_class.install_build_in_apps }.to raise_error(SystemStackError)
    end
  end
end
