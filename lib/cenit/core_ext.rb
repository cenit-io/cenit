class Hash

  def plain_query(namespace = nil)
    collect do |key, value|
      unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
        value.to_query(namespace ? "#{namespace}[#{key}]" : key)
      end
    end.compact * '&'
  end

end

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

module Spreadsheet
  class Workbook
    class << self
      def new_workbook(*args)
        args = args.collect { |a| a.capataz_proxy? ? a.capataz_slave : a }
        new(*args)
      end
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
          MIME::Mail.new
          true
        end
      end
    end
  end
end

require 'mime'

module MIME
  class Mail
    class << self
      def new_message(*args)
        new(*args)
      end
    end
  end

  class Text
    class << self
      def new_text(*args)
        new(*args)
      end
    end
  end

  class Multipart
    class Mixed

      def attach(entity, params = {})
        if entity.is_a?(Mongoff::GridFs::File)
          category, subtype = entity.contentType.split('/')
          entity =
            case category
            when 'audio'
              MIME::Audio
            when 'image'
              MIME::Image
            when 'text'
              MIME::Text
            when 'video'
              MIME::Video
            else
              MIME::Application
            end.new(entity.data, subtype, { 'Content-Type' => entity.contentType, 'name' => entity.filename })
        end
        super
      end

      class << self
        def new_message(*args)
          new(*args)
        end
      end
    end
  end
end