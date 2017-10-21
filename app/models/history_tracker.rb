require 'mongoid-audit/history_tracker'

#In order to rails_admin not to exclude HistoryTrack abstract model this file should appears under model directory
class HistoryTracker
  include Setup::CenitUnscoped
  include CrossOrigin::Document

  deny :all
  allow :history_show

  store_in collection: -> { "#{persistence_model.collection_name.to_s.singularize}_history_trackers" }

  origins -> { persistence_model.origins }

  class << self

    def persistence_model
      (persistence_options && persistence_options[:model]) || fail('Persistence option model is missing')
    end

    def storage_options_defaults
      opts = super
      if persistence_options && (model = persistence_options[:model])
        opts[:collection] = "#{model.storage_options_defaults[:collection].to_s.singularize}_history_trackers"
      end
      opts
    end

    def with(options)
      options = { model: options } unless options.is_a?(Hash)
      super
    end
  end

  rails_admin do

    configure :modified, :json_value

    configure :trackable, :record do
      visible do
        bindings[:controller].action_name == 'history_index'
      end
    end

    fields :trackable, :version, :action, :modified, :created_at
  end
end