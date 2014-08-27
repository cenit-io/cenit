require 'json'
require 'openssl'
require 'bunny'

Thread.new {

	conn = Bunny.new(:automatically_recover => false)
	conn.start

	ch   = conn.create_channel
	q    = ch.queue('send.to.website')

	begin
	  puts " [*] Waiting for messages. To exit press CTRL+C"
	  q.subscribe(:block => true) do |delivery_info, properties, body|
		puts " [x] Received #{body}"
		Cenit::Middleware::Consumer.process(body)
	  end
	rescue Interrupt => _
	  conn.close

	  exit(0)
	end

}
