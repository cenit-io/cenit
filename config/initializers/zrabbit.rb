require 'rabbit_consumer'

unless ENV['UNICORN_CENIT_SERVER'].to_b
  Cenit::Application.config.after_initialize do
    Account.all.each do |account|
      Account.current = account
      Setup::Scheduler.activated.each(&:start)
    end
    Account.current = nil
    Cenit::Rabbit.start_consumer
    Cenit::Rabbit.start_scheduler
  end
end
