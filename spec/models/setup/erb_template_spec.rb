require 'rails_helper'

describe Setup::ErbTemplate do

  test_namespace = 'ERB Template Test'
  TEST_NAME = 'Test'

  before :all do
    Setup::ErbTemplate.create(
      namespace: test_namespace,
      name: TEST_NAME,
      code: "<%= value %>"
    )
  end

  let! :test_template do
    Setup::ErbTemplate.where(namespace: test_namespace, name: TEST_NAME).first
  end

  context "when executed" do

    it "uses the input variables as locals to render" do
      value = 'Test'
      result = test_template.run(value: value)
      expect(result).to eq(value)
    end
  end

  context "when Redis client is present", if: Cenit::Redis.client? do

    context "when using capataz cache", if: ENV['CAPATAZ_CODE_CACHE'].to_b do

      it 'stores rewritten code in cache when executed' do
        Capataz::Cache.clean
        test_template.run(value: 'Test')
        expect(Capataz::Cache.size).to eq(1)
      end

      it 'cleans stored rewritten code when updated' do
        Capataz::Cache.clean
        test_template.run(value: 'Test')
        code = test_template.code
        test_template.update(code: "'Updated'")
        expect(Capataz::Cache.size).to eq(0)
        test_template.update(code: code)
      end

      it 'cleans stored rewritten code when snippet is updated' do
        Capataz::Cache.clean
        test_template.run(value: 'Test')
        code = test_template.code
        test_template.snippet.update(code: "'Updated'")
        expect(Capataz::Cache.size).to eq(0)
        test_template.snippet.update(code: code)
      end
    end
  end
end
