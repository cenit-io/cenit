module Xsd
  class Container < NamedTag

    attr_reader :tag_name
    attr_reader :max_occurs
    attr_reader :min_occurs
    attr_reader :elements

    def initialize(parent, attributes, tag_name)
      super(parent, attributes)
      @tag_name = tag_name
      _, max_occurs = attributes.detect { |a| a[0] == 'maxOccurs' }
      @max_occurs = if max_occurs then
                      max_occurs == 'unbounded' ? :unbounded : max_occurs.to_i
                    else
                      1
                    end
      _, min_occurs = attributes.detect { |a| a[0] == 'minOccurs' }
      @min_occurs = if min_occurs then
                      min_occurs == 'unbounded' ? 0 : min_occurs.to_i
                    else
                      1
                    end
      @elements = []
    end

    def when_end_xs_element(element)
      @elements << element
    end

    %w{xs:sequence xs:choice xs:all}.each do |container_tag|
      class_eval("def start_#{container_tag.gsub(':', '_')}(attributes = [])
          return Container.new(self, attributes, '#{container_tag}')
        end
      def when_end_#{container_tag.gsub(':', '_')}(container)
          container.do_product
          @elements.concat(container.elements)
      end
      def end_#{container_tag.gsub(':', '_')}
        :pop
      end")
    end

    def do_product
      @elements.each do |e|
        e.max_occurs = max_occurs == :unbounded ? :unbounded : max_occurs * max_occurs
        e.min_occurs = e.min_occurs * min_occurs
      end
      @max_occurs = @min_occurs = 1
    end
  end
end
