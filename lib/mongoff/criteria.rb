module Mongoff
  class Criteria
    include Enumerable

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
            Mongoff::Model.for(name: type)
          else
            model
          end
        next unless m.submodel_of?(model)
        yield Record.new(m, document, false)
      end
    end

    def method_missing(symbol, *args)
      if (q = query.try(symbol, *args)).is_a?(Moped::Query)
        Criteria.new(model, q)
      else
        super
      end
    end
  end
end