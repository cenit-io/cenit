module Mongoff
  class Criteria
    include Enumerable
    include Queryable

    undef_method(:sort)

    attr_reader :model
    attr_reader :query

    def initialize(model, query)
      @model = model
      @query = query
    end

    def count
      query.count
    end

    def each(*args, &blk)
      query.each do |document|
        m =
          if type = document['_type']
            model.class.for(name: type)
          else
            model
          end
        next unless m.submodel_of?(model)
        yield model.record_class.new(m, document, false)
      end
    end

    def method_missing(symbol, *args)
      query_for(model, query, symbol, *args)
    end
  end
end