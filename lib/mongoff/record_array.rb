module Mongoff
  class RecordArray
    include Enumerable

    attr_reader :model
    attr_reader :array

    def initialize(model, array, referenced = false)
      array ||= []
      @model = model
      @array = array
      @referenced = referenced
      @records = []
      array.each do |item|
        item =
          if item.is_a?(BSON::Document)
          Record.new(model, item)
        elsif item.is_a?(Mongoff::Record)
          item
        else
          model.find(item) rescue nil
          end
        @records << item if item
      end
    end

    def count
      array.count
    end

    def empty?
      @records.empty?
    end

    def each(*args, &blk)
      @records.each { |record| yield record if record } #TODO Sanitize for broken ids
    end

    def [](*several_variants)
      @records[*several_variants]
    end

    def << item
      if item.is_a?(Record) || item.class.respond_to?(:data_type) || item.is_a?(BSON::Document)
        item = Record.new(model, item) if item.is_a?(BSON::Document)
        unless @records.include?(item)
          @records << item
          if @referenced
            array << item.id unless array.include?(item.id)
          else
            array << item.attributes unless array.any? { |doc| doc['_id'] == item.id }
          end
        end
      else
        raise Exception.new("Invalid value #{item}")
      end
      item
    end

    def to_ary
      to_a
    end
  end
end