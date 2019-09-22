require 'rails_helper'

describe Setup::DelayedMessage do

  before :all do
    Setup::DelayedMessage.adapter.clean_up
  end

  before :each do
    Setup::DelayedMessage.destroy_all
  end

  let! :delayed_message do
    Setup::DelayedMessage
  end

  context "when Redis client is present", if: Cenit::Redis.client? do
    it 'uses the Redis adapter' do
      expect(delayed_message.adapter).to be Setup::DelayedMessage::RedisAdapter
    end
  end

  context "when Redis client is not present", unless: Cenit::Redis.client? do
    it 'uses the Mongoid adapter' do
      expect(delayed_message.adapter).to be Setup::DelayedMessage::MongoidAdapter
    end
  end

  context "with adapter independent behavior" do

    it 'sets created delayed messages ready' do
      msg = delayed_message.create(message: 'abc')
      record = nil
      delayed_message.for_each_ready(at: msg.publish_at + 5.seconds) do |delayed_message|
        record = delayed_message
      end
      expect(record[:message]).to eq 'abc'
    end

    it 'does not include not ready delayed messages' do
      now = Time.now
      delayed_message.create(message: 'first', publish_at: now)
      delayed_message.create(message: 'second', publish_at: now + 20.seconds)
      messages = []
      delayed_message.for_each_ready(at: now) do |delayed_message|
        messages << delayed_message[:message]
      end
      expect(messages).to eq %w(first)
    end

    it 'remove messages when destroyed' do
      now = Time.now
      first = delayed_message.create(message: 'first', publish_at: now)
      delayed_message.create(message: 'second', publish_at: now)
      first.destroy
      messages = []
      delayed_message.for_each_ready(at: now + 5.seconds) do |delayed_message|
        messages << delayed_message[:message]
      end
      expect(messages).to eq %w(second)
    end
  end
end
