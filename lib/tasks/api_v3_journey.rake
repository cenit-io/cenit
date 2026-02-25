require 'rspec/core/rake_task'

namespace :api do
  namespace :v3 do
    local_rabbit_url = 'amqp://cenit_rabbit:cenit_rabbit@127.0.0.1:5672/cenit_rabbit_vhost'.freeze

    with_local_rabbit_defaults = lambda do |&block|
      previous_rabbit = ENV['RABBITMQ_BIGWIG_TX_URL']
      ENV['RABBITMQ_BIGWIG_TX_URL'] = local_rabbit_url if previous_rabbit.nil? || previous_rabbit.empty?
      block.call
    ensure
      previous_rabbit.nil? ? ENV.delete('RABBITMQ_BIGWIG_TX_URL') : ENV['RABBITMQ_BIGWIG_TX_URL'] = previous_rabbit
    end

    desc 'Run API v3 integration journey'
    RSpec::Core::RakeTask.new('journey:run') do |t|
      t.rspec_opts = 'spec/requests/app/controllers/api/v3/integration_journey_spec.rb --tag api_journey'
    end

    desc 'Run API v3 integration journey (strict by default)'
    task :journey do
      previous = ENV['API_JOURNEY_STRICT']
      ENV['API_JOURNEY_STRICT'] = '1' if previous.nil?
      with_local_rabbit_defaults.call do
        Rake::Task['api:v3:journey:run'].reenable
        Rake::Task['api:v3:journey:run'].invoke
      end
    ensure
      previous.nil? ? ENV.delete('API_JOURNEY_STRICT') : ENV['API_JOURNEY_STRICT'] = previous
    end

    namespace :journey do
      desc 'Run API v3 integration journey in strict mode'
      task :strict do
        previous = ENV['API_JOURNEY_STRICT']
        ENV['API_JOURNEY_STRICT'] = '1'
        with_local_rabbit_defaults.call do
          Rake::Task['api:v3:journey:run'].reenable
          Rake::Task['api:v3:journey:run'].invoke
        end
      ensure
        previous.nil? ? ENV.delete('API_JOURNEY_STRICT') : ENV['API_JOURNEY_STRICT'] = previous
      end
    end
  end
end
