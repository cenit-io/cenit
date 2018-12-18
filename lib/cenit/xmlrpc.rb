module Cenit
  module XMLRPC
    extend self

    def respond_to?(*_args)
      true
    end

    def method_missing(symbol, *args)
      Encoder.encode(
        methodCall: {
          methodName: symbol,
          params: args.collect { |p| { param: Encoder.hash_encode(p) } }
        }
      )
    end

    def method_call(method, *args)
      method_missing(method, *args)
    end

    def parse(xml)
      Encoder.decode_hash_value(Hash.from_xml(xml))
    end

    module Encoder
      extend self

      def encode(value)
        xml_doc = Nokogiri::XML::Document.new
        to_xml_elements(xml_doc, value).each do |e|
          xml_doc << e
        end
        xml_doc.to_xml
      end

      def to_xml_elements(xml_doc, value)
        case value
        when Hash
          value.collect do |k, v|
            element = xml_doc.create_element(k.to_s)
            to_xml_elements(xml_doc, v).each do |e|
              element << e
            end
            element
          end
        when Array
          value.collect do |v|
            to_xml_elements(xml_doc, v)
          end.flatten
        else
          [value.to_s]
        end
      end

      def hash_encode(value)
        {
          value:
            case value
            when Integer
              { int: value }
            when Float
              { double: value }
            when Boolean, TrueClass, FalseClass
              { boolean: value ? 1 : 0 }
            when Date, Time, DateTime
              { 'dateTime.iso8601': value.to_s }
            when Hash
              {
                struct: value.collect { |k, v| { member: { name: k }.merge!(hash_encode(v)) } }
              }
            when Array
              {
                array: { data: value.collect { |v| hash_encode(v) } }
              }
            else
              { string: value.to_s }
            end
        }
      end

      def decode_hash_value(value)
        case value
        when Hash
          if value.size == 1
            k = value.keys.first
            v = value[k]
            case k
            when 'value'
              decode_hash_value(v)
            when 'string'
              v.to_s
            when 'int', 'i4'
              v.to_i
            when 'double'
              v.to_f
            when 'boolean'
              v.to_b
            when 'dateTime.iso8601'
              Time.parse(v.to_s)
            when 'struct'
              if v.is_a?(Hash) && v.size == 1 && ((members = v['member']).is_a?(Hash) || members.is_a?(Array))
                members = [members] unless members.is_a?(Array)
                members.inject({}) do |hash, member|
                  hash[member['name']] = decode_hash_value(member['value'])
                  hash
                end
              else
                hash = {}
                value.each { |k, v| hash[k] = decode_hash_value(v) }
                hash
              end
            when 'array'
              if v.is_a?(Hash) && (data = v['data']).is_a?(Hash) && data.size == 1 && ((values = data['value']).is_a?(Hash) || values.is_a?(Array))
                values = [values] unless values.is_a?(Array)
                values.collect { |v| decode_hash_value(v) }
              else
                hash = {}
                value.each { |k, v| hash[k] = decode_hash_value(v) }
                hash
              end
            else
              hash = {}
              value.each { |k, v| hash[k] = decode_hash_value(v) }
              hash
            end
          else
            hash = {}
            value.each { |k, v| hash[k] = decode_hash_value(v) }
            hash
          end
        when Array
          value.collect { |v| decode_hash_value(v) }
        else
          value
        end
      end
    end
  end
end