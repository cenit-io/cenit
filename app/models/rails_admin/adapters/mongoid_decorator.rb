module RailsAdmin
  module Adapters
    Mongoid.module_eval do

      # avoid use of alias_method in a module_eval
      def self.included(base)
        base.class_eval do
          alias_method_chain :count, :wrapper
        end
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
        end + config.extra_associations
      end
    end
  end
end
