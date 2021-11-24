require 'rails_helper'

describe Setup::Algorithm do

  test_namespace = 'Algorithm Test'

  before :all do
    Setup::Algorithm.create!(
      namespace: test_namespace,
      name: 'test',
      language: :ruby,
      code: "'Test'"
    )
  end

  let! :test do
    Setup::Algorithm.where(namespace: test_namespace, name: 'test').first
  end

  context "regardless configuration options" do

    it "link calls to other algorithms in the same namespace" do
      n = 5 + rand(5)
      ns = "#{test_namespace} SAME"
      alg = Setup::Algorithm.create!(
        namespace: ns,
        name: 'alg_0',
        language: :ruby,
        code: "0"
      )
      1.upto(n) do |i|
        alg = Setup::Algorithm.create!(
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
      ns = "#{test_namespace} X"
      alg = Setup::Algorithm.create!(
        namespace: ns,
        name: 'alg_0',
        language: :ruby,
        code: "0"
      )
      1.upto(n) do |i|
        alg = Setup::Algorithm.create!(
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

  context "javascript algorithms" do

    it "execute javascript code" do
      ns = "#{test_namespace} JS"
      cmd = Setup::Algorithm.create!(
        namespace: ns,
        name: 'cmd',
        parameters: [
          { name: 'a', type: 'number' },
          { name: 'b', type: 'number' }
        ],
        language: :javascript,
        code: "var r = a % b; if (r === 0) return b; return cmd(b, r);"
      )
      expect(cmd.run([10, 5])).to eq(5)
      expect(cmd.run([32, 24])).to eq(8)
    end
  end
end
