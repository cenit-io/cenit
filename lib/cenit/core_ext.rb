module Enumerable

  def to_xml_array(options = {})
    xml_doc = Nokogiri::XML::Document.new
    root = xml_doc.create_element(options[:root] || 'root', type: :array)
    options = options.reverse_merge(xml_doc: xml_doc)
    each do |obj|
      if (e = obj.try(:to_xml_element, options)).is_a?(Nokogiri::XML::Element)
        root << e
      end
    end
    xml_doc << root
    xml_doc.to_xml
  end

end

module OpenSSL
  class Digest
    class << self
      def new_sign(*args)
        args = args.collect { |a| a.capataz_proxy? ? a.capataz_slave : a }
        new(*args)
      end
    end
  end
end

module OpenSSL
  module PKey
    class RSA
      class << self
        def new_rsa(*args)
          args = args.collect { |a| a.capataz_proxy? ? a.capataz_slave : a }
          new(*args)
        end
      end
    end
  end
end

module Xmldsig
  class SignedDocument
    class << self
      def new_document(*args)
        args = args.collect { |a| a.capataz_proxy? ? a.capataz_slave : a }
        new(*args)
      end
    end
  end
end

class StringIO
  class << self
    def new_io(*args)
      args = args.collect { |a| a.capataz_proxy? ? a.capataz_slave : a }
      new(*args)
    end
  end
end

module Nokogiri
  module XML
    class Builder
      class << self
        def new_builder(*args)
          args = args.collect { |a| a.capataz_proxy? ? a.capataz_slave : a }
          new(*args)
        end
      end
      def respond_to?(*args)
        true
      end

      class NodeBuilder
        def respond_to?(*args)
          true
        end
      end
    end
  end
end