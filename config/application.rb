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

      RailsAdmin::Config.excluded_models.concat RailsAdmin::Config.models_pool.select { |m| m.eql?('Base') || m.end_with?('::Base') }
      puts 'Excluding ' + RailsAdmin::Config.excluded_models.to_s

      #Setup::Schema.model_listeners << RailsAdmin::AbstractModel

      testing = false

      Account.all.each do |account|

        Account.current = account

        Setup::Model.update_all(model_loaded: false, used_memory: 0)

        Setup::Schema.all.each do |schema|
          puts "Loading schema #{schema.uri}"
          schema.load_models
        end

        models = []
        Setup::FileDataType.all.each do |file_data_type|
          models << file_data_type.load_model if file_data_type.activated
        end
        RailsAdmin::AbstractModel.update_model_config(models)

        if flow = Setup::Flow.where(id: '556f66166d6163367c050000').first
          flow.process
          # data_type.load_model unless data_type.loaded?
          # model = data_type.model
          # # Setup::DataType.shutdown(data_type)
          # hooks = []
          # ObjectSpace.each_object(Object) do |obj|
          #   begin
          #     if (r = ObjectSpace.reachable_objects_from(obj)).is_a?(Enumerable) && r.include?(model)
          #       hooks << obj
          #     end
          #   rescue Exception => ex
          #     # puts ex.message
          #   end
          # end
          # puts "================================> #{hooks.size}"
          # puts hooks
          # puts 'ok!!!!!!!!!!!!!!!'
          # Setup::DataType.shutdown(data_type)
          # GC.start
          # sleep(10)
          # hooks = []
          # ObjectSpace.each_object(Object) do |obj|
          #   begin
          #     if (r = ObjectSpace.reachable_objects_from(obj)).is_a?(Enumerable) && r.include?(model)
          #       hooks << obj
          #     end
          #   rescue Exception => ex
          #     # puts ex.message
          #   end
          # end
          # puts "================================> #{hooks.size}"
          # puts hooks
        end if testing
      end
      Account.current = nil

    end

  end
end
