
unless ENV['UNICORN_CENIT_SERVER'].to_b
  Cenit::Application.config.after_initialize do
    Cenit::Rabbit.start_consumer
    puts 'RABBIT LISTENER STARTED'
  end
end
