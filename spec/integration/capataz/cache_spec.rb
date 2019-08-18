
require 'rails_helper'

describe Capataz::Cache do

  let! :cache do
    Capataz::Cache
  end

  before :each do
    cache.clean
  end

  context "when Redis client is present", if: Cenit::Redis.client? do
    it 'returns true when cleaned' do
      cache.rewrite("'Test'", code_key: 'test')
      expect(cache.clean).to be true
    end

    it 'cleans stored codes' do
      cache.rewrite("'Test'", code_key: 'test')
      cache.clean
      expect(cache.size).to eq(0)
    end

    it 'stores rewritten codes' do
      count = 1 + rand(10)
      1.upto(count).each do |i|
        cache.rewrite("'Test #{i}'", code_key: "test_#{i}")
      end
      expect(cache.size).to eq(count)
    end

    it 'does not clean stored codes with the never clean strategy' do
      cache.clean_strategy = Capataz::Cache::NEVER_CLEAN
      count = 2 * ::Cenit::Rabbit.maximum_active_tasks + 1 + rand(10)
      1.upto(count).each do |i|
        cache.rewrite("'Test #{i}'", code_key: "test_#{i}")
      end
      expect(cache.size).to eq(count)
    end

    it 'cleans stored codes with the basic clean strategy' do
      cache.clean_strategy = Capataz::Cache::BASIC_CLEAN
      max = 2 * ::Cenit::Rabbit.maximum_active_tasks
      count = 1 + rand(10)
      1.upto(max + count).each do |i|
        cache.rewrite("'Test #{i}'", code_key: "test_#{i}")
      end
      expect(cache.size).to eq(count)
    end
  end

  context "when Redis client is not present", unless: Cenit::Redis.client? do
    it 'returns false when cleaned' do
      cache.rewrite("'Test'", code_key: 'test')
      expect(cache.clean).to be false
    end

    it 'does not store rewritten codes' do
      count = 1 + rand(10)
      1.upto(count).each { |i| cache.rewrite("'Test #{i}'", code_key: "test_#{i}") }
      expect(cache.size).to eq(0)
    end
  end
end
