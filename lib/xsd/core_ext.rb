[String, Integer, Float, Mongoid::Boolean, Date, DateTime, Time].each do |klass|
  klass.class_eval("
    def self.to_json_schema
      {'$ref' => #{klass.name}}
    end
  ")
end

class NilClass
  def to_json_schema
    {}
  end
end

class String
  def to_json_schema
    key = Xsd::BUILD_IN_TYPES.keys.detect { |key| end_with?(key) }
    if key
      Xsd::BUILD_IN_TYPES[key]
    else
      { '$ref' => self }
    end
  end
end

class Hash
  def deep_reverse_merge(other)
    merge(other) do |key, left, right|
      if left.is_a?(Hash) && right.is_a?(Hash)
        left.deep_reverse_merge(right)
      else
        if key?(key)
          left
        else
          right
        end
      end
    end
  end
end