module Mongoff
  module Queryable

    def query_for(model, mongo_queryable, symbol, *args)
      criteria = nil
      if args.length == 0 ||
        (args.length == 1 && args[0].is_a?(Hash) && args[0].keys.all? { |key| key.is_a?(String) || key.is_a?(Symbol) })
        selector = {}
        args[0].each do |field, value|
          field = field.to_s == 'id' ? :_id : field.to_sym
          attribute_key = model.attribute_key(field)
          selector[attribute_key] =
            if value.is_a?(Hash)
              value
            elsif value.is_a?(Enumerable)
              value.collect { |v| model.mongo_value(v, field) }
            else
              model.mongo_value(value, field)
            end
        end unless args.length == 0
        if (query = (selector.present? ? mongo_queryable.try(symbol, selector) : mongo_queryable.try(symbol))).is_a?(Moped::Query)
          criteria = Criteria.new(model, query)
        end
      end
      criteria
    end
  end
end