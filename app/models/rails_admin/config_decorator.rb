module RailsAdmin
  Config.module_eval do

    class << self

      def model(entity, &block)
        key = nil
        model_class =
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

        if block
          model = model_class.new(entity, &block)
          @registry[key] = model if key
        elsif key
          unless (model = @registry[key])
            @registry[key] = model = model_class.new(entity)
          end
        else
          model = model_class.new(entity)
        end
        model
      end
    end

  end
end
