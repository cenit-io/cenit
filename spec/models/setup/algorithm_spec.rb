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

    it "link calls to other algorithms in the same namespace" do
      n = 5 + rand(5)
      ns = "#{TEST_NAMESPACE} SAME"
      alg = Setup::Algorithm.create(
        namespace: ns,
        name: 'alg_0',
        language: :ruby,
        code: "0"
      )
      1.upto(n) do |i|
        alg = Setup::Algorithm.create(
          namespace: ns,
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

    it "link calls to other algorithms with different namespaces" do
      n = 5 + rand(5)
      ns = "#{TEST_NAMESPACE} X"
      alg = Setup::Algorithm.create(
        namespace: ns,
        name: 'alg_0',
        language: :ruby,
        code: "0"
      )
      1.upto(n) do |i|
        alg = Setup::Algorithm.create(
          namespace: "#{ns} #{i}",
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
