require 'mongoid/tracer/trace'

module Mongoid
  module Tracer

    def trace_scope
      target_id = id
      proc { |scope| scope.where(target_id: target_id) }
    end


    class Trace
      include Setup::CenitUnscoped
      include CrossOrigin::Document

      deny :all
      allow :trace_show

      store_in collection: -> { "#{persistence_model.collection_name.to_s.singularize}_traces" }

      origins -> { persistence_model.origins }

      class << self

        def persistence_model
          (persistence_options && persistence_options[:model]) || fail('Persistence option model is missing')
        end

        def storage_options_defaults
          opts = super
          if persistence_options && (model = persistence_options[:model])
            opts[:collection] = "#{model.storage_options_defaults[:collection].to_s.singularize}_traces"
          end
          opts
        end

        def with(options)
          options = { model: options } unless options.is_a?(Hash)
          super
        end
      end

      rails_admin do

        configure :target, :record do
          visible do
            bindings[:controller].action_name == 'trace_index'
          end
        end

        configure :attributes_trace, :json_value

        fields :target, :action, :attributes_trace, :created_at
      end
    end
  end
end
