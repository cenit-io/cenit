module Mongoff
  module Queryable

    def query_for(model, mongo_queryable, symbol, *args)
      criteria = nil
      if args.length == 1 && args[0].is_a?(Hash) && args[0].keys.all? { |key| key.is_a?(String) || key.is_a?(Symbol) }
        selector = {}
        args[0].each do |field, value|
          field = field.to_s == 'id' ? :_id : field.to_sym
          attribute_key = model.attribute_key(field)
          selector[attribute_key] =
            if symbol == :sort || value.is_a?(Hash)
              value
            elsif value.is_a?(Enumerable)
              value.collect { |v| model.mongo_value(v, field) }
            else
              model.mongo_value(value, field)
            end
        end unless args.length == 0
      else
        selector = args
      end
      query =
        if selector.present?
          selector.is_a?(Array) ? mongo_queryable.try(symbol, *selector) : mongo_queryable.try(symbol, selector)
        else
          mongo_queryable.try(symbol)
        end
      criteria = Mongoff::Criteria.new(model, query) if query.is_a?(Moped::Query)
      criteria
    end
  end
end