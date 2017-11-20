module RailsAdmin
  module Config
    module Actions
      class CollectionTraceIndex < RailsAdmin::Config::Actions::TraceIndex

        register_instance_option :collection do
          true
        end

        def trace_scope
          model_constraints = {}
          if (model = bindings[:abstract_model].model).is_a?(Class) && model < ::Setup::ClassHierarchyAware
            model_constraints[:target_model_name.in] = bindings[:abstract_model].model.class_hierarchy.collect(&:to_s)
          else
            model_constraints[:target_model_name] = model.to_s
          end
          proc do |scope|
            scope.where(model_constraints)
          end
        end

      end
    end
  end
end