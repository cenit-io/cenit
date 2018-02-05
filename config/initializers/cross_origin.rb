module CrossOrigin
  module CenitDocument
    extend ActiveSupport::Concern

    include CrossOrigin::Document

    def can_cross?(origin)
      (self.origin != :shared || User.current_cross_shared? || Cenit.initializing?) && super
    end

    module ClassMethods

      def cross_origins
        if @origins
          @origins.collect do |origin|
            if origin.respond_to?(:call)
              origin.call
            else
              origin
            end
          end.flatten.uniq.compact.collect do |origin|
            if origin.is_a?(Symbol)
              origin
            else
              origin.to_s.to_sym
            end
          end.uniq
        elsif superclass.include?(CrossOrigin::CenitDocument)
          superclass.origins
        elsif superclass.include?(CrossOrigin::Document)
          superclass.origins
        else
          CrossOrigin.names
        end
      end

      def origins(*args)
        if args.length == 0
          origins = []
          acc = ::Account.current
          super.each do |origin|
            origin_param="#{origin}_origin"
            origins << origin if (acc && (acc.meta || {})[origin_param]).to_i.even?
          end
          origins
        else
          super
        end
      end
    end
  end
end

CrossOrigin.config :shared
CrossOrigin.config :admin
CrossOrigin.config :owner, collection: ->(model) do
  user = Cenit::MultiTenancy.tenant_model.current_tenant.owner
  "user#{user.id}_#{model.mongoid_root_class.storage_options_defaults[:collection]}"
end
CrossOrigin.config :cenit
CrossOrigin.config :tmp
CrossOrigin.config :app, collection: ->(_) do
  Cenit::MultiTenancy.tenant_model.tenant_collection_name(Setup::Application)
end