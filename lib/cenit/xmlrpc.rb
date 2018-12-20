module Cenit
  module XMLRPC
    extend self

    def respond_to?(*_args)
      true
    end

    def method_missing(symbol, *args)
      body_request = {
        :methodCall => {
          :methodName => symbol
        }
      }
      body_request[:methodCall][:params] = args.collect { |p| { param: Encoder.hash_encode(p) } } unless args.empty?
      Encoder.encode(body_request)
    end

    def method_call(method, *args)
      method_missing(method, *args)
    end

    def parse_method_response(xml)
      parsing_xml = Encoder.hash_decode(Hash.from_xml(xml))
      raise "No valid method response!" unless parsing_xml['methodName'].nil?
      parsing_xml = parsing_xml['methodResponse']
      if parsing_xml['fault'] != nil
        # is a fault structure
        [false, parsing_xml['fault']]
      else
        # is a normal return value
        raise "Missing return value!" if parsing_xml['params'].length == 0
        raise "Too many return values. Only one allowed!" if parsing_xml['params'].length > 1
        [true, parsing_xml['params']['param']]
      end
    end

    def parse(xml)
      Encoder.hash_decode(Hash.from_xml(xml))
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

      def hash_decode(value)
        case value
        when Hash
          r = nil
          if value.size == 1
            k = value.keys.first
            v = value[k]
            r =
              case k
              when 'value'
                hash_decode(v)
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
                    hash[member['name']] = hash_decode(member['value'])
                    hash
                  end
                else
                  nil
                end
              when 'array'
                if v.is_a?(Hash) && (data = v['data']).is_a?(Hash) && data.size == 1 && ((values = data['value']).is_a?(Hash) || values.is_a?(Array))
                  values = [values] unless values.is_a?(Array)
                  values.collect { |v| hash_decode(v) }
                else
                  nil
                end
              else
                nil
              end
          else
            nil
          end
          r ||
            begin
              hash = {}
              value.each { |k, v| hash[k] = hash_decode(v) }
              hash
            end
        when Array
          value.collect { |v| hash_decode(v) }
        else
          value
        end
      end
    end
  end
end
