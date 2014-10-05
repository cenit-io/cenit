require 'json'
require 'openssl'
require 'bunny'

Thread.new {

  conn = Bunny.new(:automatically_recover => false)
  conn.start

  ch   = conn.create_channel
  q    = ch.queue('send.to.endpoint')

  begin
    puts " [*] Waiting for messages. To exit press CTRL+C"
    q.subscribe(:block => true) do |delivery_info, properties, body|
      puts " [x] Received #{body}"
      Cenit::Rabbit.send_to_endpoint(body)
    end
  rescue Interrupt => _
    conn.close

    exit(0)
  end

}
