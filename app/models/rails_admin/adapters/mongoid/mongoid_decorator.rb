require 'rails_admin/adapters/mongoid'

module RailsAdmin
  module Adapters
    module Mongoid

      alias_method :rails_admin_query_conditions, :query_conditions

      def query_conditions(query, fields = nil)
        if fields.nil? && (model = config.abstract_model.model).is_a?(Class) && model < Setup::ClassHierarchyAware
          statements = []
          model.class_hierarchy.each do |model|
            next if model.abstract_class
            fields = RailsAdmin.config(model).list.fields.select(&:queryable?)
            model_statements = []

            fields.each do |field|
              conditions_per_collection = make_field_conditions(field, query, field.search_operator)
              model_statements.concat make_condition_for_current_collection(field, conditions_per_collection)
            end

            if model_statements.any?
              statements << { '_type' => model.model_name, '$or' => model_statements }
            end
          end
          if statements.any?
            { '$or' => statements }
          else
            {}
          end
        else
          rails_admin_query_conditions(query, fields)
        end
      end

      AbstractObject.module_eval do

        def send(*args, &block)
          if object.is_a?(Mongoff::Record)
            object.send(*args, &block)
          else
            super
          end
        end
      end
    end
  end
end
