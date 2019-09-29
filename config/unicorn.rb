# Set your full path to application.

app_dir = File.expand_path('../../', __FILE__)
shared_dir = File.expand_path('../../../shared/', __FILE__)
app_name = "cenit"

# Set unicorn options
config =
  begin
    require 'psych'
    Psych.load(File.read("#{app_dir}/config/application.yml"))
  rescue
    {}
  end
listen 8080
worker_processes config['UNICORN_WORKERS'] || 5
preload_app config.key?('UNICORN_PRELOAD') ? config['UNICORN_PRELOAD'].to_b : true
timeout config['UNICORN_TIMEOUT'] || 240

GC.respond_to?(:copy_on_write_friendly=) and GC.copy_on_write_friendly = true

# Fill path to your app
working_directory app_dir

# Set up socket location
listen "#{shared_dir}/sockets/unicorn.#{app_name}.sock", backlog: 64

# Loging
stderr_path "#{shared_dir}/log/unicorn.#{app_name}.stderr.log"
stdout_path "#{shared_dir}/log/unicorn.#{app_name}.stdout.log"

# Set master PID location
pid "#{shared_dir}/pids/unicorn.#{app_name}.pid"

before_fork do |server, worker|
  Cenit::Rabbit.close
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!
  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
  sleep 1
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
  defined?(Rails) and Rails.cache.respond_to?(:reconnect) and Rails.cache.reconnect

  if worker.nr.zero?
    unless ENV['SKIP_DB_INITIALIZATION']
      Tenant.all.each do |tenant|
        tenant.switch do
          Setup::Scheduler.activated.each(&:start)
        end
      end
    end
    Cenit::Rabbit.start_scheduler
  elsif worker.nr <= Cenit.maximum_unicorn_consumers
    Cenit::Rabbit.start_consumer
  end
end

before_exec do |server|
  ENV['BUNDLE_GEMFILE'] = "#{app_dir}/Gemfile"
end
