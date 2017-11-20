module RailsAdmin
  module Config
    module Actions
      class MemberTraceIndex < RailsAdmin::Config::Actions::TraceIndex

        register_instance_option :member do
          true
        end

        def trace_scope
          target_id = bindings[:object].id
          proc do |scope|
            scope.where(target_id: target_id)
          end
        end

      end
    end
  end
end