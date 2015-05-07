module Mongoff
  module Queryable

    def query_for(model, mongo_queryable, symbol, *args)
      criteria = nil
      if args.length == 0 ||
        (args.length == 1 && args[0].is_a?(Hash) && args[0].keys.all? { |key| key.is_a?(String) || key.is_a?(Symbol) })
        selector = {}
        args[0].each do |field, value|
          field = field.to_s == 'id' ? :_id : field.to_sym
          selector[field] = model.mongo_value(value, field)
        end unless args.length == 0
        if (query = mongo_queryable.try(symbol, selector)).is_a?(Moped::Query)
          criteria = Criteria.new(self, query)
        end
      end
      criteria
    end
  end
end