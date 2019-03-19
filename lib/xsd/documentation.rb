module Xsd
  class Documentation < AttributedTag

    tag 'documentation'

    attr_reader :source

    def initialize(args)
      super
      @source = attributeValue(:source, args[:attributes])
      @elements = { characters: '' }
      @elements_stack = [@elements]
    end

    def empty?
      @elements.size == 1 && @elements[:characters].empty?
    end

    def characters(string)
      unless (string = string.strip).empty?
        unless @elements_stack.last[:characters].empty?
          string = ". #{string}"
        end
        @elements_stack.last[:characters] += string
      end
    end

    def start_element_tag(name, attributes = [])
      new_element = { characters: '' }
      name = name.split(':').last.to_title
      top_element = @elements_stack.last
      if (entry = top_element[name]).nil?
        top_element[name] = new_element
      elsif entry.is_a?(Array)
        entry << new_element
      else
        top_element[name] = [entry, new_element]
      end
      @elements_stack << new_element
      nil
    end

    def end_element_tag(_)
      @elements_stack.pop
      nil
    end

    def to_description
      description =
        if @elements.size == 1
          @elements[:characters]
        else
          @elements
        end
      description = { source => description } if source
      to_html(description)
    end

    def to_html(content)
      case content
      when Array
        "<ul>\n" + content.collect { |value| "<li>\n" + to_html(value) + "\n</li>" }.join("\n") + '</ul>'
      when Hash
        html = content.delete(:characters).to_s
        unless content.empty?
          html = "#{html}\n<ul>\n" +
                 content.collect do |key, value|
                   "<li>\n<strong>#{key}:</strong> " + to_html(value) + "\n</li>"
                 end.join("\n") + '</ul>'
        end
        html
      else
        content.to_s
      end
    end

    protected :to_html
  end
end