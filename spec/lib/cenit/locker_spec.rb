require 'rails_helper'

describe Cenit::Locker do

  let! :locker do
    Cenit::Locker
  end

  before :each do
    locker.clear
  end

  context "when Redis client is present", if: Cenit::Redis.client? do
    it 'uses the Redis adapter' do
      expect(locker.adapter).to be Cenit::Locker::RedisAdapter
    end
  end

  context "when Redis client is not present", unless: Cenit::Redis.client? do
    it 'uses the Mongoid adapter' do
      expect(locker.adapter).to be Cenit::Locker::MongoidAdapter
    end
  end

  context "with adapter independent behavior" do
    it 'returns true when testing lock for locked objects' do
      locker.lock('test')
      expect(locker.locked?('test')).to be true
    end

    it 'returns false when testing lock for unlocked objects' do
      locker.lock('test')
      locker.unlock('test')
      expect(locker.locked?('test')).to be false
    end

    it 'executes the block when locking unlocked objects' do
      executed = false
      locker.locking('test') do
        executed = true
      end
      expect(executed).to be true
    end

    it 'does not execute the block when locking locked objects' do
      locker.lock('test')
      executed = false
      locker.locking('test') do
        executed = true
      end
      expect(executed).to be false
    end

    it 'clears locks' do
      count = 1 + rand(10)
      1.upto(count).each do |i|
        locker.lock("test##{i}")
      end
      locker.clear
      1.upto(count).each do |i|
        expect(locker.locked?("test##{i}")).to be false
      end
    end
  end
end
