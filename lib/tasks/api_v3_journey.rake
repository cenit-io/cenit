require 'rspec/core/rake_task'

namespace :api do
  namespace :v3 do
    desc 'Run API v3 integration journey (stable mode with documented fallbacks)'
    RSpec::Core::RakeTask.new('journey:run') do |t|
      t.rspec_opts = 'spec/requests/app/controllers/api/v3/integration_journey_spec.rb --tag api_journey'
    end

    desc 'Run API v3 integration journey (stable mode with documented fallbacks)'
    task :journey do
      Rake::Task['api:v3:journey:run'].reenable
      Rake::Task['api:v3:journey:run'].invoke
    end

    namespace :journey do
      desc 'Run API v3 integration journey in strict mode (no fallback paths)'
      task :strict do
        previous = ENV['API_JOURNEY_STRICT']
        ENV['API_JOURNEY_STRICT'] = '1'
        Rake::Task['api:v3:journey:run'].reenable
        Rake::Task['api:v3:journey:run'].invoke
      ensure
        previous.nil? ? ENV.delete('API_JOURNEY_STRICT') : ENV['API_JOURNEY_STRICT'] = previous
      end
    end
  end
end
