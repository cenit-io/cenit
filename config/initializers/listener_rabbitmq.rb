require 'json'
require 'openssl'
require 'bunny'

Thread.new {
  conn = Bunny.new(:automatically_recover => false)
  conn.start

  ch = conn.create_channel
  q = ch.queue('cenit')

  begin
    q.subscribe(block: true) do |delivery_info, properties, body|
      Cenit::Rabbit.process_message(body)
    end
  rescue Interrupt => _
    conn.close
    exit(0)
  end
}
