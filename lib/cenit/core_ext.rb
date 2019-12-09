class Module
  class << self

    def demongoize(object)
      object.to_s.constantize
    rescue
      nil
    end

    def mongoize(object)
      object.to_s
    end
  end
end

class Thread

  def clean_keys_prefixed_with(prefix)
    unless (prefix = prefix.to_s).empty?
      Thread.current.keys.each { |key| Thread.current[key] = nil if key.to_s.start_with?(prefix) }
    end
  end

  class << self
    def clean_keys_prefixed_with(prefix)
      current.clean_keys_prefixed_with(prefix)
    end
  end
end

class Hash
  def plain_query(namespace_or_opts = nil)
    namespace =
      if (options = namespace_or_opts).is_a?(Hash)
        namespace_or_opts[:namespace]
      else
        options = {}
        namespace_or_opts
      end
    collect do |key, value|
      unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
        key = namespace ? "#{namespace}[#{key}]" : key
        if options[:skip_encoding]
          "#{key}=#{value}"
        else
          value.to_query(key)
        end
      end
    end.compact * '&'
  end

  def each_deep_pair(&block)
    each_pair do |key, value|
      if yield(self, key, value)
        case value
        when Hash
          value.each_deep_pair(&block)
        when Array
          value.each { |sub_value| sub_value.each_deep_pair(&block) if sub_value.is_a?(Hash) }
        end
      end
    end if block
  end

  def intersection(other)
    hash = {}
    each do |key, value|
      if (other_value = other[key]).is_a?(Hash) && value.is_a?(Hash)
        hash[key] = value.intersection(other_value)
      elsif Cenit::Utility.eql_content?(value, other[key])
        hash[key] = value
      end
    end
    hash
  end

  def difference(other)
    hash = {}
    other.each do |other_key, other_value|
      unless has_key?(other_key)
        hash[other_key] = other_value
      end
    end
    each do |key, value|
      if (other_value = other[key]).is_a?(Hash) && value.is_a?(Hash)
        unless (diff = value.difference(other_value)).empty?
          hash[key] = diff
        end
      elsif !Cenit::Utility.eql_content?(value, other[key])
        hash[key] = value
      end
    end
    hash
  end

  def array_hash_merge(other)
    deep_merge(other) { |_, value, other_value| Cenit::Utility.array_hash_merge(value, other_value) }
  end

  def reverse_array_hash_merge(other)
    other.array_hash_merge(self)
  end

  def www_form_encode
    URI.encode_www_form(self)
  end
end

class Numeric

  def to_time_span(metric = :s)
    v = self.abs.to_i
    str = ''
    h = {
      ms: 1000,
      s: 1000,
      m: 60,
      h: 60,
      d: 24
    }
    current_metric = metric
    h.keys.each do|m|
      h.delete(m)
      break if m == current_metric
    end
    scaled_v = 0
    h.each do |m, scale|
      if (scaled_v = v / scale).positive?
        str = "#{v % scale}#{current_metric} #{str}"
        v = scaled_v
        current_metric = m
      else
        str = "#{v}#{current_metric} #{str}"
        break
      end
    end
    if scaled_v.positive?
      str = "#{v}#{current_metric} #{str}"
    end
    str
  end
end

class String

  def to_title
    title =
      gsub(/([A-Z])(\d)/, '\1 \2').
        gsub(/([a-z])(\d|[A-Z])/, '\1 \2').
        gsub(/(\d)([a-z]|[A-Z])/, '\1 \2').
        tr('_', ' ').
        tr('-', ' ').
        strip
    unless title.empty?
      title[0] = title[0].mb_chars.capitalize.to_s
    end
    title
  end

  def sym2word
    str = self
    {
      '+' => 'plus',
      '@' => 'at',
      '$' => 'dollar',
      '%' => 'percentage',
      '?' => 'question',
      '=' => 'equals',
      '*' => 'asterisk',
      '&' => 'and'
    }.each do |char, word|
      str = str.squeeze(char).gsub(char, word)
    end
    str
  end

  def to_file_name
    gsub(/ |\/|\\/, '_').squeeze('_')
  end

  def to_method_name(taken = nil)
    str = sym2word
    {
      '-' => 'minus',
      '.' => 'dot'
    }.each do |char, replacement|
      ch = true
      while ch && (ch = str[0]) =~ /\W/
        str = str.from(1)
        if ch == char
          str = "#{replacement}#{str}"
          ch = false
        end
      end
      ch = true
      while ch && (ch = str.last) =~ /\W/
        str = str.to(str.length - 2)
        if ch == char
          str = "#{str}#{replacement}"
          ch = false
        end
      end
      str = str.squeeze(char).gsub(char, '_')
    end
    if (str = str.gsub(/\W/, '')).empty?
      str = '_property'
    else
      str = "_#{str}" unless str =~ /\A(_|[A-Za-z])/
    end
    taken_method =
      case taken
      when Hash
        :key?
      when Enumerable
        :include?
      else
        nil
      end
    if taken_method && taken.send(taken_method, str)
      i = 1
      i += 1 while taken.send(taken_method, "#{str}_#{i}")
      "#{str}_#{i}"
    else
      str
    end
  end

  def to_plural(count = nil, locale = :en)
    p = []
    tokens = strip.squeeze(' ').split(' ')
    while (last = tokens.pop) && last.match(/\W\Z/)
      p << last
    end
    if last
      tokens << last
      last = tokens.join(' ').pluralize(count, locale)
    else
      last = ''
    end
    p.unshift(last)
    p.join(' ')
  end

  def hmac_sha256(key)
    OpenSSL::HMAC.digest(openssl_digest[:sha256], key.to_s, self)
  end

  def hmac_hex_sha256(key)
    OpenSSL::HMAC.hexdigest(openssl_digest[:sha256], key.to_s, self)
  end

  def sha256
    openssl_digest[:sha256].digest(self)
  end

  def hex_sha256
    openssl_digest[:sha256].hexdigest(self)
  end

  def to_hex
    each_byte.map { |b| b.to_s(16) }.join
  end

  def openssl_digest
    @openssl_digest ||= Hash.new { |h, k| h[k] = OpenSSL::Digest.new(k.to_s) }
  end

  private :openssl_digest
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
  MIME::Multipart::Mixed => :new_message,
  WriteXLSX => :new_xlsx,
  MIME::Application => :new_app,
  MIME::Image => :new_img,
  MIME::DiscreteMedia => :new_media,
  CombinePDF => :new_pdf,
  MWS::Feeds::Client => :new_feed,
}.each do |entity, method|
  entity.class_eval("def self.#{method}(*args)
    new(*args)
  end")
end

{
  MIME::DiscreteMedia => :create_media,
  MIME::DiscreteMediaFactory => :create_factory
}.each do |entity, method|
  entity.class_eval("def self.#{method}(*args)
    create(*args)
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

require 'therubyracer'

class Object
  def ruby_class
    self.class
  end
end

class V8::Conversion
  module Reference
    def self.construct!(object)
      context = V8::Context.current
      constructor = context.to_v8(object.ruby_class)
      reference = constructor.NewInstance([V8::C::External::New(object)])
      return reference
    end
  end
end

require 'bson/object_id'

module BSON
  class ObjectId

    def to_liquid
      self
    end
  end
end

require 'zip'
require 'zip/entry'

module Zip
  def decode(zipped_data)
    file = Tempfile.new('zipped_data', encoding: 'ascii-8bit')
    file.write(result = zipped_data)
    file.rewind
    Zip::File.open_buffer(file) { |zf| result = yield(zf.entries) }
    result
  ensure
    file.close
    file.unlink
  end

  def encode(entries, entry_prefix = nil)
    zip = Zip::OutputStream.write_buffer { |zip| do_encode(zip, entries, entry_prefix) }
    zip.rewind
    zip.sysread
  end

  def do_encode(zip, entries, entry_prefix = nil)
    entries.each do |name, data|
      entry_name = entry_prefix ? "#{entry_prefix}/#{name}" : name
      if data.is_a?(Hash)
        do_encode(zip, data, entry_name)
      else
        zip.put_next_entry(entry_name)
        zip.write(data.to_s)
      end
    end
  end

  class Entry

    def read
      get_input_stream.read
    end
  end
end
