require File.expand_path('../boot', __FILE__)

# require 'rails/all'
require "action_controller/railtie"
require "action_mailer/railtie"
# require "active_resource/railtie"
require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Cenit
  class Application < Rails::Application

    config.autoload_paths += %W(#{config.root}/lib) #/**/*.rb
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.after_initialize do

      puts 'DELETING OLD Consumers'
      RabbitConsumer.delete_all

      model_update_options = { model_loaded: false, used_memory: 0 }
      if Cenit.deactivate_models
        model_update_options[:activated] = false
        model_update_options[:show_navigation_link] = false
      end

      Account.all.each do |account|

        Account.current = account

        Setup::DataType.update_all(model_update_options)

        unless Cenit.deactivate_models
          models = Set.new
          Setup::JsonDataType.activated.each do |data_type|
            models += data_type.load_models[:loaded]
          end
          Setup::FileDataType.activated.each do |file_data_type|
            models << file_data_type.load_model
          end
          RailsAdmin::AbstractModel.update_model_config(models)
        end

        ThreadToken.destroy_all
        Setup::Task.all.any_in(status: Setup::Task::RUNNING_STATUS).update_all(status: :broken)

      end

      Account.current = nil
    end

    if Rails.env.production?
      Rails.application.config.middleware.use ExceptionNotification::Rack,
                                              :email => {
                                                :email_prefix => "[Cenit Error #{Rails.env}] ",
                                                :sender_address => %{"notifier" <#{ENV['NOTIFIER_EMAIL']}>},
                                                :exception_recipients => ENV['EXCEPTION_RECIPIENTS'].split(',')
                                              }
    end

  end
end
