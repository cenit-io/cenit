require 'rails_helper'

describe Setup::Snippet do

  TEST_NAMESPACE = 'Snippet Test'

  before :all do
    %w(default owner shared).each do |origin|
      Setup::Snippet.create(
        namespace: TEST_NAMESPACE,
        name: "#{origin}_test.rb",
        code: "'Test'",
        origin: origin
      )
    end
  end

  before :each do
    Capataz::Cache.clean
  end

  let! :first_tenant do
    Tenant.where(name: User.current.email).first
  end

  let! :second_tenant do
    Tenant.find_or_create_by(name: 'Second')
  end

  let! :default_snippet do
    Setup::Snippet.where(namespace: TEST_NAMESPACE, name: 'default_test.rb').first
  end

  let! :owner_snippet do
    Setup::Snippet.where(namespace: TEST_NAMESPACE, name: 'owner_test.rb').first
  end

  let! :shared_snippet do
    Setup::Snippet.where(namespace: TEST_NAMESPACE, name: 'shared_test.rb').first
  end

  context "when Redis client is present", if: Cenit::Redis.client? do

    it 'stores rewritten code in cache when using default code key' do
      Capataz::Cache.rewrite(default_snippet.code, code_key: default_snippet.code_key)
      expect(Capataz::Cache.size).to eq(1)
    end

    it 'stores rewritten code in cache when using owner code key' do
      Capataz::Cache.rewrite(owner_snippet.code, code_key: owner_snippet.code_key)
      expect(Capataz::Cache.size).to eq(1)
    end

    it 'does not store cache when using the same owner code key' do
      first_tenant.switch do
        Capataz::Cache.rewrite(owner_snippet.code, code_key: owner_snippet.code_key)
      end
      second_tenant.switch do
        Capataz::Cache.rewrite(owner_snippet.code, code_key: owner_snippet.code_key)
      end
      expect(Capataz::Cache.size).to eq(1)
    end

    it 'stores rewritten code in cache when using shared code key' do
      Capataz::Cache.rewrite(shared_snippet.code, code_key: shared_snippet.code_key)
      expect(Capataz::Cache.size).to eq(1)
    end

    it 'does not store cache when using the same shared code key' do
      first_tenant.switch do
        Capataz::Cache.rewrite(owner_snippet.code, code_key: shared_snippet.code_key)
      end
      second_tenant.switch do
        Capataz::Cache.rewrite(owner_snippet.code, code_key: shared_snippet.code_key)
      end
      expect(Capataz::Cache.size).to eq(1)
    end

    it 'cleans stored rewritten code when updated' do
      Capataz::Cache.clean
      Capataz::Cache.rewrite(default_snippet.code, code_key: default_snippet.code_key)
      default_snippet.update(code: "'Updated'")
      expect(Capataz::Cache.size).to eq(0)
    end
  end
end
