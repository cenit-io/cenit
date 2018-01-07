# rails_admin-1.0 ready
require 'rails_admin/adapters/mongoid'

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
          if (model_config = config.ready)
            model_config.extra_associations
          else
            []
          end
      end

      def all(options = {}, scope = nil)
        scope ||= scoped
        scope = scope.includes(*options[:include]) if options[:include]
        scope = scope.limit(options[:limit]) if options[:limit]
        scope = scope.any_in(_id: options[:bulk_ids]) if options[:bulk_ids]
        scope = scope.where(query_conditions(options[:query])) if options[:query]
        scope = scope.where(filter_conditions(options[:filters])) if options[:filters]
        scope = scope.and(filter_query_conditions(options[:filter_query])) if options[:filter_query]
        if (criteria = options[:criteria])
          unless criteria.is_a?(Hash)
            criteria =
              begin
                JSON.parse(criteria.to_s)
              rescue
                {}
              end
            criteria = {} unless criteria.is_a?(Hash)
            criteria = validate_criteria(criteria)
            scope = scope.where(criteria)
          end
        end
        if options[:page] && options[:per]
          scope = scope.send(Kaminari.config.page_method_name, options[:page]).per(options[:per])
        end
        scope = sort_by(options, scope) if options[:sort]
        scope
      end

      def validate_criteria(criteria)
        if criteria.is_a?(Hash)
          criteria.each do |key, value|
            if key.start_with?('$') && %w($and $or $in).exclude?(key)
              criteria.delete(key)
            elsif value.is_a?(Hash)
              if (value = validate_criteria(value)).empty?
                criteria.delete(key)
              else
                criteria[key] = value
              end
            end
          end
        else
          criteria
        end
      end

      def filter_query_conditions(query, fields = nil)
        fields_query_conditions(:filter_query_fields, query, fields)
      end

      def query_conditions(query, fields = nil)
        fields_query_conditions(:fields, query, fields)
      end

      def fields_query_conditions(fields_method, query, fields = nil)
        #Patch
        statements = []
        if fields.nil? && model.is_a?(Class) && model < Setup::ClassHierarchyAware
          model.class_hierarchy.each do |model|
            next if model.abstract_class
            model_statements = []
            model_config = RailsAdmin.config(model)

            fields = model_config.send(fields_method).select(&:queryable?)
            fields.each do |field|
              conditions_per_collection = make_field_conditions(field, query, field.search_operator)
              model_statements.concat make_condition_for_current_collection(field, conditions_per_collection)
            end

            [model_config.search_associations].flatten.each do |association_name|
              next unless (association = model.reflect_on_association(association_name))
              model_config = RailsAdmin.config(association.klass)
              associated_selector = model_config.abstract_model.fields_query_conditions(fields_method, query)
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
          fields ||= config.send(fields_method).select(&:queryable?)
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

      def get(id)
        #Patch
        return nil unless (obj = model.find(id))
        RailsAdmin::Adapters::Mongoid::AbstractObject.new(obj)
      rescue => e
        raise e if %w(
          Mongoid::Errors::DocumentNotFound
          Mongoid::Errors::InvalidFind
          Moped::Errors::InvalidObjectId
          BSON::InvalidObjectId
        ).exclude?(e.class.to_s)
      end

      def properties
        fields = model.fields.reject { |_name, field| RailsAdmin::Adapters::Mongoid::DISABLED_COLUMN_TYPES.include?(field.type.to_s) }
        fields.collect do |_name, field|
          RailsAdmin::Adapters::Mongoid::Property.new(field, model)
        end +
          if (model_config = config.ready)
            model_config.extra_associations
          else
            []
          end
      end

      def filter_conditions(filters, fields = config.filter_fields)
        statements = []

        filters = JSON.parse(filters).with_indifferent_access if filters.is_a?(String)

        filters.each_pair do |field_name, filters_dump|
          if field_name.start_with?('$')
            if filters_dump.is_a?(Array)
              statements << { field_name => filters_dump.collect { |f| filter_conditions(f, fields) } }
            else
              statements << { field_name => filter_conditions(filters_dump, fields) }
            end
          else
            field = fields.detect { |f| f.name.to_s == field_name }
            next unless field
            filters_dump.each do |_, filter_dump|
              value = parse_field_value(field, filter_dump[:v])
              if field.is_a?(RailsAdmin::Config::Fields::Types::BelongsToAssociation)
                associated_am = field.associated_model_config.abstract_model
                value = { '$in' => associated_am.model.where(associated_am.filter_query_conditions(value)).collect(&:id) }
              end
              conditions_per_collection = make_field_conditions(field, value, (filter_dump[:o] || 'default'))
              field_statements = make_condition_for_current_collection(field, conditions_per_collection)
              if field_statements.many?
                statements << { '$or' => field_statements }
              elsif field_statements.any?
                statements << field_statements.first
              end
            end
          end
        end

        statements.any? ? { '$and' => statements } : {}
      end
    end
  end
end
