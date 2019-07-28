require 'rails_helper'

describe Setup::DelayedMessage do

  before :each do
    Setup::DelayedMessage.delete_all
    Setup::DelayedMessage.load_on_start
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

  context "when adapter is NOT default Mongoid", unless: Setup::DelayedMessage.adapter == Setup::DelayedMessage::MongoidAdapter do

    it 'sets the load_on_start flag' do
      delayed_message.set_load_on_start(false)
      delayed_message.set_load_on_start(true)
      expect(delayed_message.load_on_start?).to be true
    end

    it 'removes load_on_start flag' do
      delayed_message.set_load_on_start(true)
      delayed_message.set_load_on_start(false)
      expect(delayed_message.load_on_start?).to be false
    end

    it 'executes the load_on_start block' do
      delayed_message.set_load_on_start(true)
      loaded = false
      delayed_message.adapter.load_on_start do
        loaded = true
      end
      expect(loaded).to be true
    end

    it 'does not execute the load_on_start block' do
      delayed_message.set_load_on_start(false)
      loaded = false
      delayed_message.adapter.load_on_start do
        loaded = true
      end
      expect(loaded).to be false
    end

    it 'remove the load_on_start flag when loading on start' do
      delayed_message.set_load_on_start(true)
      delayed_message.adapter.load_on_start
      expect(delayed_message.load_on_start?).to be false
    end

    it 'set ready created delayed messages' do
      delayed_message.create(message: 'abc')
      record = nil
      delayed_message.for_each_ready(at: Time.now + 1.minute) do |delayed_message|
        record = delayed_message
      end
      expect(record[:message]).to eq 'abc'
    end
  end
end
