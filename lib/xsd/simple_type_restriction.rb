module Xsd
  class SimpleTypeRestriction < BasicTag

    tag 'restriction'

    attr_reader :base
    attr_reader :restrictions

    def initialize(parent, base, restrictions=nil)
      super(parent)
      @base = base
      @restrictions = {}
      restrictions.each { |key, value| @restrictions[key] = value } if restrictions
    end

    def start_element_tag(name, attributes)
      unless %w{annotation documentation}.include?(name)
        if name == 'enumeration'
          @restrictions[name] ||= []
          @restrictions[name] << attributes
        else
          @restrictions[name] = attributes
        end
      end
      nil
    end

    def to_json_schema
      json = qualify_type(base).to_json_schema
      @restrictions.each do |key, value|
        restriction =
          case key
          when 'enumeration'
            {'enum' => value.collect { |v| v[0][1] }.uniq}
          when 'length'
            {'minLength' => value[0][1].to_i, 'maxLength' => value[0][1].to_i}
          when 'pattern'
            {'pattern' => value[0][1]}
          when 'minInclusive'
            {'minimum' => value[0][1].to_i}
          when 'maxInclusive'
            {'maximum' => value[0][1].to_i}
          when 'minExclusive'
            {'minimum' => value[0][1].to_i, 'exclusiveMinimum' => true}
          when 'maxExclusive'
            {'maximum' => value[0][1].to_i, 'exclusiveMaximum' => true}
          when 'fractionDigits'
            {'multipleOf' => 1.0/(10 ** value[0][1].to_i)}
          when 'totalDigits' #TODO Fractions digits count in total
            {'minimum' => 10 ** (value[0][1].to_i - 1), 'maximum' => 10 ** value[0][1].to_i - 1}
          else
            #TODO simpleType and whiteScpace restrictions
            {(key = key.gsub('xs:', '')) => value[0][1].to_i} unless value.empty?
          end
        json = json.merge(restriction) if restriction
      end
      return json
    end

  end
end