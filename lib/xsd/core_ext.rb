[String, Integer, Float, Boolean, Date, DateTime, Time].each do |klass|
  klass.class_eval("
    def self.to_json_schema
      {type: #{klass.name}}
    end
  ")
end

module Xsd
  BUILD_IN_TYPES = {'xs:decimal' => {'type' => 'integer'},
                    'xs:float' => {'type' => 'number'},
                    'xs:double' => {'type' => 'number'},
                    'xs:integer' => {'type' => 'integer'},
                    'xs:positiveInteger' => {'type' => 'integer', 'minimum' => 0, 'exclusiveMinimum' => true},
                    'xs:negativeInteger' => {'type' => 'integer', 'maximum' => 0, 'exclusiveMaximum' => true},
                    'xs:nonPositiveInteger' => {'type' => 'integer', 'maximum' => 0},
                    'xs:nonNegativeInteger' => {'type' => 'integer', 'minimum' => 0},
                    'xs:long' => {'type' => 'integer'},
                    'xs:int' => {'type' => 'integer'},
                    'xs:short' => {'type' => 'integer'},
                    'xs:byte' => {'type' => 'integer'},
                    'xs:unsignedLong' => {'type' => 'integer', 'minimum' => 0},
                    'xs:unsignedInt' => {'type' => 'integer', 'minimum' => 0},
                    'xs:unsignedShort' => {'type' => 'integer', 'minimum' => 0},
                    'xs:unsignedByte' => {'type' => 'integer', 'minimum' => 0},
                    'xs:date' => {'$ref' => 'Date'},
                    'xs:dateTime' => {'$ref' => 'DateTime'},
                    'xs:gYearMonth' => {'$ref' => 'Date'},
                    'xs:gYear' => {'$ref' => 'Date'},
                    'xs:duration' => {'type' => 'string', 'pattern' => 'P([0-9]*Y)?([0-9]*M)?([0-9]*D)?(T([0-9]*H)?([0-9]*M)?([0-9]*S)?)?'},
                    'xs:time' => {'$ref' => 'Time'},
                    'xs:gMonthDay' => {'$ref' => 'Date'},
                    'xs:gMonth' => {'$ref' => 'Date'},
                    'xs:gDay' => {'$ref' => 'Date'},
                    'xs:string' => {'type' => 'string'},
                    'xs:token' => {'type' => 'string'},
                    'xs:language' => {'type' => 'string', 'enum' => %w{en es}},
                    'xs:NMTOKEN' => {'type' => 'string'},
                    'xs:NMTOKENS' => {'type' => 'string'},
                    'xs:Name' => {'type' => 'string'},
                    'xs:NameNC' => {'type' => 'string'},
                    'xs:ID' => {'type' => 'string'},
                    'xs:IDREF' => {'type' => 'string'},
                    'xs:IDREFS' => {'type' => 'string'},
                    'xs:ENTITY' => {'type' => 'string'},
                    'xs:ENTITIES' => {'type' => 'string'},
                    'xs:QName' => {'type' => 'string'},
                    'xs:boolean' => {'type' => 'boolean'},
                    'xs:hexBinary' => {'type' => 'integer'},
                    'xs:base64Binary' => {'type' => 'integer'},
                    'xs:anyURI' => {'type' => 'string'},
                    'xs:notation' => {'type' => 'string'}}.freeze
end

class String
  def to_json_schema
    Xsd::BUILD_IN_TYPES[self] || {'$ref' => self}
  end
end