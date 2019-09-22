require 'rails_helper'

describe Setup::Algorithm do

  TEST_NAMESPACE = 'Algorithm Test'

  before :all do
    Setup::Algorithm.create(
      namespace: TEST_NAMESPACE,
      name: 'test',
      language: :ruby,
      code: "'Test'"
    )
  end

  let! :test_algorithm do
    Setup::Algorithm.where(namespace: TEST_NAMESPACE, name: 'test').first
  end

  context "when Redis client is present", if: Cenit::Redis.client? do

    context "when using capataz cache", if: ENV['CAPATAZ_CODE_CACHE'].to_b do

      it 'stores rewritten code in cache when executed' do
        Capataz::Cache.clean
        test_algorithm.run
        expect(Capataz::Cache.size).to eq(1)
      end

      it 'cleans stored rewritten code when updated' do
        Capataz::Cache.clean
        test_algorithm.run
        test_algorithm.update(code: "'Updated'")
        expect(Capataz::Cache.size).to eq(0)
      end

      it 'cleans stored rewritten code when snippet is updated' do
        Capataz::Cache.clean
        test_algorithm.run
        test_algorithm.snippet.update(code: "'Updated (again)'")
        expect(Capataz::Cache.size).to eq(0)
      end
    end
  end
end
