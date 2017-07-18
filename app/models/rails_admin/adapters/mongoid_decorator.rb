# rails_admin-1.0 ready
module RailsAdmin
  module Adapters
    Mongoid.module_eval do

      ALIAS_METHODS = proc do
        alias_method_chain :count, :wrapper
      end

      # avoid use of alias_method in a module_eval
      def self.included(base)
        base.class_eval(&ALIAS_METHODS)
      end

      def self.extended(base)
        base.class_eval(&ALIAS_METHODS)
      end

      def counts(options = {}, scope = nil)
        key = "[cenit]#{model_name}.counts"
        if (cache = options.delete(:cache)) && (counts = RequestStore.store[key])
          counts
        else
          counts =
            case scope = all(options.merge(limit: false, page: false), scope)
            when CrossOrigin::Criteria
              hash = {}
              scope.view.cross_view_map.each do |origin, view|
                hash[origin] = view.count
              end
              hash
            else
              { default: scope.count }
            end
          if cache
            RequestStore.store[key] = counts
            RequestStore.store["[cenit]#{model_name}.count"] ||= counts.values.first
          end
          counts
        end
      end

      def count_with_wrapper(options = {}, scope = nil)
        if options.delete(:cache)
          key = "[cenit]#{model_name}.count"
          if (count = RequestStore.store[key])
            count
          else
            RequestStore.store[key] = count_without_wrapper(options, scope)
          end
        else
          count_without_wrapper(options, scope)
        end
      end

      def sort_by(options, scope)
        return scope unless options[:sort]

        case options[:sort]
        when String
          #Patch
          collection_name = (sort = options[:sort])[0..i = sort.rindex('.') - 1]
          field_name = sort.from(i + 2)
          if collection_name && collection_name != table_name
            fail('sorting by associated model column is not supported in Non-Relational databases')
          end
        when Symbol
          field_name = options[:sort].to_s
        end
        #Patch
        if field_name.present?
          if options[:sort_reverse]
            scope.asc field_name
          else
            scope.desc field_name
          end
        else
          scope
        end
      end

      def parse_collection_name(column)
        #Patch
        collection_name = column[0..i = column.rindex('.') - 1]
        column_name = column.from(i + 2)
        if [:embeds_one, :embeds_many].include?(model.relations[collection_name].try(:macro).try(:to_sym))
          [table_name, column]
        else
          [collection_name, column_name]
        end
        [collection_name, column_name]
      end

      def associations
        model.relations.values.collect do |association|
          RailsAdmin::Adapters::Mongoid::Association.new(association, model)
        end + #Patch
          case (model_config = config)
          when RailsAdmin::Config::Model
            model_config.extra_associations
          else
            []
          end
      end

      def query_conditions(query, fields = nil)
        #Patch
        statements = []
        if fields.nil? && model.is_a?(Class) && model < Setup::ClassHierarchyAware
          model.class_hierarchy.each do |model|
            next if model.abstract_class
            model_statements = []
            model_config = RailsAdmin.config(model)

            fields = model_config.fields.select(&:queryable?)
            fields.each do |field|
              conditions_per_collection = make_field_conditions(field, query, field.search_operator)
              model_statements.concat make_condition_for_current_collection(field, conditions_per_collection)
            end

            [model_config.search_associations].flatten.each do |association_name|
              next unless (association = model.reflect_on_association(association_name))
              model_config = RailsAdmin.config(association.klass)
              associated_selector = model_config.abstract_model.query_conditions(query)
              if associated_selector.any?
                associated_ids = association.klass.where(associated_selector).collect(&:id)
                model_statements << {
                  association.foreign_key =>
                    if association.many?
                      { '$elemMatch' => q = {} }
                    else
                      q = {}
                    end
                }
                q['$in'] = associated_ids.uniq
              end
            end

            if model_statements.any?
              statements << { '_type' => model.model_name, '$or' => model_statements }
            end
          end
        else
          fields ||= config.fields.select(&:queryable?)
          fields.each do |field|
            conditions_per_collection = make_field_conditions(field, query, field.search_operator)
            statements.concat make_condition_for_current_collection(field, conditions_per_collection)
          end
        end
        if statements.any?
          { '$or' => statements }
        else
          {}
        end
      end
    end
  end
end
