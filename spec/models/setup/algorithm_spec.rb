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

  let! :test do
    Setup::Algorithm.where(namespace: TEST_NAMESPACE, name: 'test').first
  end

  context "regardless configuration options" do

    it "link calls to other algorithms" do
      n = 5 + rand(5)
      alg = Setup::Algorithm.create(
        namespace: TEST_NAMESPACE,
        name: 'alg_0',
        language: :ruby,
        code: "0"
      )
      1.upto(n) do |i|
        alg = Setup::Algorithm.create(
          namespace: "#{TEST_NAMESPACE} #{i}",
          name: "alg_#{i}",
          language: :ruby,
          code: "alg_#{i - 1}"
        )
      end
      n.times do
        result = alg.run
        expect(result).to eq(0)
      end
    end
  end

  context "when Redis client is present", if: Cenit::Redis.client? do

    context "when using capataz cache", if: ENV['CAPATAZ_CODE_CACHE'].to_b do

      it 'stores rewritten code in cache when executed' do
        Capataz::Cache.clean
        test.run
        expect(Capataz::Cache.size).to eq(1)
      end

      it 'cleans stored rewritten code when updated' do
        Capataz::Cache.clean
        test.run
        test.update(code: "'Updated'")
        expect(Capataz::Cache.size).to eq(0)
      end

      it 'cleans stored rewritten code when snippet is updated' do
        Capataz::Cache.clean
        test.run
        test.snippet.update(code: "'Updated (again)'")
        expect(Capataz::Cache.size).to eq(0)
      end
    end
  end
end
