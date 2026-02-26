# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
# require 'rspec/autorun'
require 'ffaker'
require 'factory_girl_rails'
require 'database_cleaner'

if defined?(ActiveRecord::TestFixtures)
  module NoActiveRecordFixtures
    def setup_fixtures(*args)
      return unless active_record_pool_available?
      super
    end

    def teardown_fixtures(*args)
      return unless active_record_pool_available?
      super
    end

    private

    def active_record_pool_available?
      ActiveRecord::Base.connection_pool
      true
    rescue ActiveRecord::ConnectionNotEstablished
      false
    end
  end

  ActiveRecord::TestFixtures.prepend(NoActiveRecordFixtures)
end

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
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
  # This app is Mongoid-backed; disable AR fixture wiring in rspec-rails.
  config.use_active_record = false
  config.use_transactional_fixtures = false

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include RSpec::Matchers
  config.include FactoryGirl::Syntax::Methods

  config.include Warden::Test::Helpers

  config.include Api::V3::Test
  config.include Api::V3::RequestHelper, type: :request

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  ensure_test_tenant_context = lambda do
    test_user = ::User.current || ::User.all.first
    unless test_user
      test_user = ::User.create!(
        email: ENV.fetch('DEFAULT_USER_EMAIL', 'support@cenit.io'),
        password: ENV.fetch('DEFAULT_USER_PASSWORD', 'password')
      )
    end
    ::User.current = test_user

    account =
      test_user.account ||
      test_user.accounts.first ||
      ::Account.where(owner_id: test_user.id).first ||
      ::Account.current

    unless account
      account = ::Account.new_for_create(owner: test_user, owner_id: test_user.id, name: test_user.email)
      account.save!
    end

    if test_user.account_id != account.id
      test_user.set(account: account, api_account: (test_user.api_account || account))
      test_user.save!
    end

    account.switch
  end

  config.before(:suite) do
    # DatabaseCleaner.strategy = :truncation
    ensure_test_tenant_context.call
  end
  config.before(:each) do
    ensure_test_tenant_context.call
    #DatabaseCleaner.start
    #Mongoid.default_client.collections.select { |c| c.name !~ /system/ }.each(&:drop)
    # Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
  end
  config.after(:each) do
    #Warden.test_reset!
    #  DatabaseCleaner.clean
  end
  config.after(:suite) do
    Mongoid.default_client.database.drop
  end
end
