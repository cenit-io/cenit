# rails_admin-1.0 ready
module RailsAdmin
  Config.module_eval do

    class << self

      def model(entity, &block)
        key = nil
        model_class = #Patch
          if entity.is_a?(Mongoff::Model) || entity.is_a?(Mongoff::Record) || entity.is_a?(RailsAdmin::MongoffAbstractModel)
            RailsAdmin::MongoffModelConfig
          else
            key =
              case entity
              when RailsAdmin::AbstractModel
                entity.model.try(:name).try :to_sym
              when Class
                entity.name.to_sym
              when String, Symbol
                entity.to_sym
              else
                entity.class.name.to_sym
              end
            RailsAdmin::Config::LazyModel
          end

        #Patch
        model = model_class.new(entity)
        model.add_deferred_block(&block) if block && model_class == RailsAdmin::Config::LazyModel
        @registry[key] = model if key

        model
      end
    end

  end
end
