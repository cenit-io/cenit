module Setup
  module AffectRelationMethods
    def model_access_name
      to_s
    end

    def affected_models
      (collect_models_from(@_affected_model_names ||= Set.new) + other_affected_models).uniq
    end

    def other_affected_models
      []
    end

    def affected_by
      (collect_models_from(@_affected_by ||= Set.new) + other_affected_by).uniq
    end

    def other_affected_by
      []
    end

    def affects_to(model)
      (@_affected_model_names ||= Set.new) << model.model_access_name
      unless affected_by = model.instance_variable_get(:@_affected_by)
        model.instance_variable_set(:@_affected_by, affected_by = Set.new)
      end
      affected_by << model_access_name
    end

    private

    def collect_models_from(constant_names)
      models = []
      constant_names.each do |model_name|
        if model = model_name.constantize rescue nil
          models << model
        else
          constant_names.delete(model_name)
        end
      end
      models
    end
  end
end
