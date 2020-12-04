require File.expand_path('../boot', __FILE__)

# require 'rails/all'
require "action_controller/railtie"
require "action_mailer/railtie"
# require "active_resource/railtie"
require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Setup; end

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
    #
    config.load_defaults '5.2'

    config.to_prepare do
      # Load application's model / class decorators
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
      Dir.glob(File.join(File.dirname(__FILE__), "../lib/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.after_initialize do

      eager_load!

      Thread.current[:cenit_initializing] = true

      default_user_email = ENV['DEFAULT_USER_EMAIL'] || 'support@cenit.io'

      User.current = User.where(email: default_user_email).first ||
        User.with_role(Role.find_or_create_by(name: :super_admin).name).first ||
        User.create!(email: default_user_email, password: ENV['DEFAULT_USER_PASSWORD'] || 'password')

      unless ENV['SKIP_DB_INITIALIZATION'].to_b
        Setup::DelayedMessage.do_load unless ENV['SKIP_LOAD_DELAYED_MESSAGES'].to_b

        puts 'Clearing LOCKS'
        Cenit::Locker.clear

        puts 'DELETING CANCELLED Consumers'
        RabbitConsumer.where(alive: false).delete_all

        Capataz::Cache.clean

        setup_build_in_apps_types

        Setup::CenitDataType.init!

        Mongoff::Model.config do
          before_save ->(record) do
            record.updated_at = DateTime.now
            if record.new_record?
              record.created_at = record.updated_at
            elsif record.orm_model.observable?
              record.instance_variable_set(:@_obj_before, record.orm_model.where(id: record.id).first)
            end
            true
          end

          after_save ->(record) do
            if record.orm_model.observable? && !record.instance_variable_get(:@discard_event_lookup)
              Setup::Observer.lookup(record, record.instance_variable_get(:@_obj_before))
            end
            record.remove_instance_variable(:@discard_event_lookup) if record.instance_variable_defined?(:@discard_event_lookup)
          end
        end
      end

      require 'mongoff/model'
      require 'mongoff/record'

      Mongoff::Model.include(Mongoid::Tracer::Options::ClassMethods)
      Mongoff::Record.class_eval do
        include Mongoid::Tracer::DocumentExtension
        include Mongoid::Tracer::TraceableDocument

        def tracing?
          self.class.data_type.trace_on_default && super
        end

        def set_association_values(association_name, values)
          send("#{association_name}=", values)
        end
      end

      unless ENV['SKIP_DB_INITIALIZATION'].to_b
        setup_build_in_apps

        Setup::Oauth2Provider.build_in_provider_id

        Tenant.all.each do |tenant|
          tenant.switch do
            ThreadToken.destroy_all
            Setup::Task.where(:status.in => Setup::Task::ACTIVE_STATUS).update_all(status: :broken)
            Setup::Execution.where(:status.nin => Setup::Task::FINISHED_STATUS).update_all(status: :broken, completed_at: Time.now)

            Setup::Application.all.update_all(provider_id: Setup::Oauth2Provider.build_in_provider_id)
          end
        end
      end

      Thread.current[:cenit_initializing] = nil
    end

    if Rails.env.production? &&
      (notifier_email = ENV['NOTIFIER_EMAIL']) &&
      (exception_recipients = ENV['EXCEPTION_RECIPIENTS'])
      Rails.application.config.middleware.use ExceptionNotification::Rack,
                                              email: {
                                                email_prefix: "[Cenit Error #{Rails.env}] ",
                                                sender_address: %{"notifier" <#{notifier_email}>},
                                                exception_recipients: exception_recipients.split(','),
                                                sections: %w(tenant request session environment backtrace)
                                              }
    end

    def self.setup_build_in_apps_types
      BuildInApps.apps_modules.each do |app_module|
        app_module.document_types_defs.each do |name, spec|
          # Model def
          type = Class.new
          app_module.const_set(name.to_s, type)
          type.include(Setup::CenitScoped)
          type.build_in_data_type
          type.class_eval(&spec)
        end
      end
    end

    def self.setup_build_in_apps
      puts 'Creating build-in apps'
      BuildInApps.apps_modules.each do |app_module|
        namespace = app_module.to_s.split('::')
        name = namespace.pop
        namespace = namespace.join('::')
        app = Cenit::BuildInApp.find_or_create_by(namespace: namespace, name: name)
        if app.persisted?
          puts "App #{app_module} is persisted..."
          app.check_tenant &:save!
          app_id = app.application_id
          app_id.slug = app_module.app_key
          app_id.oauth_name = app_module.app_name
          app_id.trusted = true
          app_id.save!
          app_module.instance_variable_set(:@app_id, app.id)
          tenant = app.tenant
          meta_key = "app_#{app.id}"
          if (tenant.meta[meta_key] || {})['installed']
            puts "#{app_module} already installed!"
          else
            puts "Installing #{app_module}..."
            tenant.switch do
              app_module.installers.each do |install_block|
                app_module.instance_eval(&install_block)
              end
            end
            tenant.meta[meta_key] = (tenant.meta[meta_key] || {}).merge('installed' => true)
            tenant.save
          end
          puts "Setting up #{app_module}..."
          tenant.switch do
            app_module.setups.each do |setup_block|
              app_module.instance_eval(&setup_block)
            end
          end
          puts "App #{app_module} ready!"
        else
          puts "Couldn't create build-in app #{app_module}: #{app.errors.full_messages.to_sentence}"
        end
      end
    end
  end
end
