# rails_admin-1.0 ready

require 'mongoff/model'
require 'rails_admin/lib/mongoff_abstract_model'

module RailsAdmin
  Config.module_eval do

    class << self

      def model(entity, &block)
        model = #Patch
          if entity.is_a?(Mongoff::Model) || entity.is_a?(Mongoff::Record) || entity.is_a?(RailsAdmin::MongoffAbstractModel)
            RailsAdmin::MongoffModelConfig.new(entity)
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
            @registry[key] ||= RailsAdmin::Config::LazyModel.new(entity)
          end

        model.add_deferred_block(&block) if block
        model
      end
    end

  end
end
