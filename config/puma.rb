
workers ENV.fetch('UNICORN_WORKERS', 5).to_i

preload_app!

on_worker_boot do |n|
  if n.zero?
    unless ENV['SKIP_DB_INITIALIZATION'].to_b
      Tenant.all.each do |tenant|
        tenant.switch do
          Setup::Scheduler.activated.each(&:start)
        end
      end
    end
    Cenit::Rabbit.start_scheduler || Cenit::Rabbit.start_consumer
  elsif n <= Cenit.maximum_unicorn_consumers
    Cenit::Rabbit.start_consumer
  end
end