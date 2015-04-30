module Mongoff
  class RecordArray
    include Enumerable

    attr_reader :model
    attr_reader :array

    def initialize(model, array, referenced = false)
      @model = model
      @array = array
      @referenced = referenced
      @records = array.collect { |item| item.is_a?(BSON::Document) ? Record.new(model, item) : item }
    end

    def count
      array.count
    end

    def each(*args, &blk)
      @records.each { |record| yield record }
    end

    def [](*several_variants)
      @records[*several_variants]
    end

    def << item
      if item.is_a?(Record) || item.class.respond_to?(:data_type) || item.is_a?(BSON::Document)
        item = Record.new(model, item) if item.is_a?(BSON::Document)
        unless @records.include?(item)
          @records << item
          array << (@referenced ? item.id : item.attributes)
        end
      else
        raise Exception.new("Invalid value #{item}")
      end
    end
  end
end