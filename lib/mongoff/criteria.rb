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
      query.each { |document| yield Record.new(model, document) }
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