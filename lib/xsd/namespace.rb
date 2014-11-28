module Xsd
  class Namespace

    BUILD_IN_TYPES = {'xs:decimal' => Float,
                      'xs:float' => Float,
                      'xs:double' => Float,
                      'xs:integer' => Integer,
                      'xs:positiveInteger' => Xsd::PositiveInteger,
                      'xs:negativeInteger' => Xsd::NegativeInteger,
                      'xs:nonPositiveInteger' => Xsd::NonPositiveInteger,
                      'xs:nonNegativeInteger' => Xsd::NonNegativeInteger,
                      'xs:long' => Integer,
                      'xs:int' => Integer,
                      'xs:short' => Integer,
                      'xs:byte' => Integer,
                      'xs:unsignedLong' => Xsd::NonNegativeInteger,
                      'xs:unsignedInt' => Xsd::NonNegativeInteger,
                      'xs:unsignedShort' => Xsd::NonNegativeInteger,
                      'xs:unsignedByte' => Xsd::NonNegativeInteger,
                      'xs:date' => Date,
                      'xs:dateTime' => DateTime,
                      'xs:gYearMonth' => Date,
                      'xs:gYear' => Date,
                      'xs:duration' => Xsd::Duration,
                      'xs:time' => Time,
                      'xs:gMonthDay' => Time,
                      'xs:gMonth' => Time,
                      'xs:gDay' => Time,
                      'xs:string' => String,
                      'xs:token' => String,
                      'xs:language' => String,
                      'xs:NMTOKEN' => String,
                      'xs:NMTOKENS' => String,
                      'xs:Name' => String,
                      'xs:NameNC' => String,
                      'xs:ID' => String,
                      'xs:IDREF' => String,
                      'xs:IDREFS' => String,
                      'xs:ENTITY' => String,
                      'xs:ENTITIES' => String,
                      'xs:QName' => String,
                      'xs:boolean' => Boolean,
                      'xs:hexBinary' => Integer,
                      'xs:base64Binary' => Integer,
                      'xs:anyURI' => String,
                      'xs:notation' => String}.freeze

    attr_reader :uri
    attr_reader :includes

    def initialize(uri)
      @uri = uri
      @types = {}
      @includes = []

      Namespace[uri] = self
    end

    def [](key)
      value = BUILD_IN_TYPES[key] || @types[key]
      return value if value
      includes.each { |schema| return schema[key] if schema[key] }
      return nil
    end

    def []=(key, value)
      @types[key] = value
    end

    def modelize
      @types.each { |key, value| @types[key] = value.to_model rescue value }
    end

    class << self
      def [](key)
        @schemas ||= {}
        @schemas[key]
      end

      def []=(key, value)
        (@schemas ||= {})[key] = value
      end
    end
  end
end