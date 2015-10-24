module Mongoff
  class Criteria
    include Enumerable
    include Origin::Queryable

    attr_reader :model

    def initialize(model)
      super(Aliases.new(model), Hash.new { |h, k| h[k] = Serializer.new(model, k) })
      @model = model
    end

    def count
      query.count
    end

    def size
      count
    end

    def query
      q = model.collection.find(selector)
      options.each do |option, criterion|
        q = q.send(option, criterion)
      end
      q
    end

    def merge(other)
      crit = clone
      crit.merge!(other)
      crit
    end

    def to_criteria
      self
    end

    def merge!(other)
      criteria = other.to_criteria
      selector.merge!(criteria.selector)
      options.merge!(criteria.options)
      self
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
      if (q = query).respond_to?(symbol)
        q.send(symbol, *args)
      else
        super
      end
    end

    def find(*args)
      case (docs = any_in(id: args).to_a).length
      when 0
        nil
      when 1
        docs[0]
      else
        docs
      end
    end

    private

    class Aliases

      attr_reader :model

      def initialize(model)
        @model = model
      end

      def [](field)
        model.attribute_key(field)
      end
    end

    class Serializer

      attr_reader :model
      attr_reader :field

      def initialize(model, field)
        @model = model
        @field = model.properties.detect { |key| model.attribute_key(key).to_s == field } || field.to_sym
      end

      def localized?
        false
      end

      def evolve(value)
        if value.respond_to?(:orm_model) && value.respond_to?(:id)
          value.id
        elsif value.is_a?(Hash)
          value
        elsif value.is_a?(Enumerable)
          value.collect { |v| model.mongo_value(v, field) }
        else
          model.mongo_value(value, field)
        end
      end
    end
  end
end