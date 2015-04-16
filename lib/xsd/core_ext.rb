[String, Integer, Float, Boolean, Date, DateTime, Time].each do |klass|
  klass.class_eval("
    def self.to_json_schema
      {'$ref' => #{klass.name}}
    end
  ")
end

class NilClass
  def to_json_schema
    { }
  end
end

class String
  def to_json_schema
    if key = Xsd::BUILD_IN_TYPES.keys.detect { |key| end_with?(key) }
      Xsd::BUILD_IN_TYPES[key]
    else
      {'$ref' => self}
    end
  end

  def to_title
    self.
      gsub(/([A-Z])(\d)/, '\1 \2').
      gsub(/([a-z])(\d|[A-Z])/, '\1 \2').
      gsub(/(\d)([a-z]|[A-Z])/, '\1 \2').
      tr('_', ' ').
      tr('-', ' ')
  end
end