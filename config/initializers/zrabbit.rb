
unless ENV['UNICORN_CENIT_SERVER'].to_b
  Cenit::Application.config.after_initialize do
    Cenit::Rabbit.start_consumer
    Cenit::Rabbit.start_scheduler
    Setup::Scheduler.activated.each(&:start)
  end
end
