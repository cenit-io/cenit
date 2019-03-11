# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
# require 'rspec/autorun'
require 'ffaker'
require 'factory_girl_rails'
require 'database_cleaner'
require 'simplecov'
require 'coveralls'

require 'capybara/poltergeist'

Capybara.javascript_driver = :poltergeist

# Increase default wait time from 2 seconds as needed.
Capybara.default_wait_time = 6

# Set an explicit server_port so we can use it later to set the URL for multi-tenancy testing
Capybara.server_port = "8200"

# Configure selenium/chrome for testing via capybara
Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

# Set RAILS_TEST_BROWSER to selenium or firefox for firefox,
# chrome (or nothing) for chrome, or webkit for webkit
browser = ENV['RAILS_TEST_BROWSER'] || 'chrome'
Capybara.default_driver = Capybara.javascript_driver = browser.to_sym

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter]

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/bundle/'
  minimum_coverage(91.65)
end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
# ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

module Devise
  module Models
    module DatabaseAuthenticatable
      protected

      def password_digest(password)
        password
      end
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include RSpec::Matchers
  config.include RailsAdmin::Engine.routes.url_helpers
  config.include FactoryGirl::Syntax::Methods

  config.include Warden::Test::Helpers

  config.include Capybara::DSL, type: :request

  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # #config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # #config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  # config.order = "random"

  config.before(:suite) do
    # DatabaseCleaner.strategy = :truncation
    test_user = ::User.create!(email: 'test@cenit.io', password: '12345678')
    ::User.current = test_user
    test_user.accounts.first.switch
  end
  config.before(:each) do
    #DatabaseCleaner.start
    #Mongoid.default_client.collections.select { |c| c.name !~ /system/ }.each(&:drop)
    # Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    #RailsAdmin::Config.reset
    #RailsAdmin::AbstractModel.reset
  end
  config.after(:each) do
    #Warden.test_reset!
    #  DatabaseCleaner.clean
  end
  config.after(:suite) do
    Mongoid.default_client.database.drop
  end
end
