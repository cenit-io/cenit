module RailsAdmin
  module Config
    module Fields
      module Types
        class ContextualBelongsTo < RailsAdmin::Config::Fields::Types::BelongsToAssociation

          def with(bindings)
            if (controller = bindings[:controller]) &&
               (obj = bindings[:object]) && (context_id = controller.get_context_id(association.klass))
              if obj.new_record?
                obj.send("#{foreign_key}=", context_id)
              end
            end
            super
          end

          register_instance_option :include_blanks_on_collection_scope do
            false
          end

          register_instance_option :associated_collection_scope do
            limit = (associated_collection_cache_all ? nil : 30)
            associated = (obj = bindings[:object]) && obj.send(association.name)
            Proc.new do |scope|
              if associated
                scope.where(id: associated.id)
              else
                scope
              end.limit(limit)
            end
          end

          register_instance_option :partial do
            associated = bindings[:object].send(association.name)
            if associated
              if bindings[:controller].get_context_record.nil?
                bindings[:controller].process_context(model: association.klass, record: associated)
              end
              :selected_field
            else
              :form_filtering_select
            end
          end

        end
      end
    end
  end
end