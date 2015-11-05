require 'json'
require 'openssl'
require 'bunny'

unless ENV['UNICORN_CENIT_SERVER'].to_b

  puts 'RABBIT LISTENER STARTED'

  Cenit::Rabbit.start_consumer

end
