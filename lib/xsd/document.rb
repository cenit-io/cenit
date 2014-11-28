module Xsd
  class Document < Nokogiri::XML::SAX::Document

    [Element, ComplexType, SimpleType].each do |tag_type|
      class_eval("def start_#{tag_type.tag_name.gsub(':', '_')}(attributes = [])
          #{tag_type}.new(top_if_available, attributes)
        end")
    end

    attr_reader :uri
    attr_reader :schema

    def initialize(uri, str_doc)
      @uri = uri
      @stack = [:floor, @schema = Xsd::Schema.new]

      parser = Nokogiri::XML::SAX::Parser.new(self)
      parser.parse(str_doc)
    end

    def start_element(name, attributes = [])
      primary_method = "start_#{name.gsub(':', '_')}".to_sym
      push process_element_message(primary_method, :start_element, name, attributes)
    end

    def end_element(name)
      primary_method = "end_#{name.gsub(':', '_')}".to_sym
      if (element = push process_element_message(primary_method, :end_element, name)) &&
                            top.respond_to?(parent_callback_method = "when_#{primary_method}".to_sym)
        top.send(parent_callback_method, element)
      end
    end

    private

    def process_element_message(primary_method, alternative_method, name, attributes=nil)
      if top.respond_to?(primary_method)
        if attributes
          return top.send(primary_method, attributes)
        end

        return top.send(primary_method)
      elsif top_available? && top.respond_to?(alternative_method)
        if attributes
          return top.send(alternative_method, name, attributes)
        end

        return top.send(alternative_method, name)
      elsif self.respond_to?(primary_method)
        if attributes
          return self.send(primary_method, attributes)
        end

        return self.send(primary_method)
      end

      return nil
    end

    def push(obj)
      if obj == :pop
        @stack.pop
      else
        @stack << obj if obj
      end
    end

    def pop
      @stack.last == :floor ? self : @stack.pop
    end

    def pop!
      pop while top_available?
      @stack.pop
      @stack << :floor if @stack.empty?
    end

    def top
      @stack.last == :floor ? self : @stack.last
    end

    def top_if_available
      top_available? ? top : nil
    end

    def top_available?
      @stack.last != :floor
    end
  end
end