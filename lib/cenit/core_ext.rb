class Hash
  def plain_query(namespace = nil)
    collect do |key, value|
      unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
        value.to_query(namespace ? "#{namespace}[#{key}]" : key)
      end
    end.compact * '&'
  end

  def each_deep_pair(&block)
    each_pair do |key, value|
      yield(self, key, value)
      case value
      when Hash
        value.each_deep_pair(&block)
      when Array
        value.each { |sub_value| sub_value.each_deep_pair(&block) if sub_value.is_a?(Hash) }
      end
    end if block_given?
  end

end

class String
  def to_title
    self.
      gsub(/([A-Z])(\d)/, '\1 \2').
      gsub(/([a-z])(\d|[A-Z])/, '\1 \2').
      gsub(/(\d)([a-z]|[A-Z])/, '\1 \2').
      tr('_', ' ').
      tr('-', ' ').
      capitalize
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

{
  OpenSSL::Digest => :new_sign,
  OpenSSL::Digest::SHA1 => :new_sha1,
  OpenSSL::PKey::RSA => :new_rsa,
  OpenSSL::X509::Certificate => :new_certificate,
  Xmldsig::SignedDocument => :new_document,
  StringIO => :new_io,
  Spreadsheet::Workbook => :new_workbook,
  Nokogiri::XML::Builder => :new_builder,
  MIME::Mail => :new_message,
  MIME::Message => :new_message,
  MIME::Text => :new_text,
  MIME::Multipart::Mixed => :new_message
}.each do |entity, method|
  entity.class_eval("def self.#{method}(*args)
    new(*args)
  end")
end


module Nokogiri
  module XML

    class Builder

      def respond_to?(*args)
        true
      end

      class NodeBuilder
        def respond_to?(*args)
          true
        end
      end
    end

    class SyntaxError
      def empty?
        false
      end
    end
  end
end

require 'mime'

module MIME
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
    end
  end
end
