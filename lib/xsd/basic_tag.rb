module Xsd
  class BasicTag

    attr_reader :parent

    def initialize(parent)
      @parent = parent
    end

    def tag_name
      self.class.tag_name rescue nil
    end

    def self.tag(name)
      class_eval("
          def self.tag_name
            '#{name}'
          end")
      class_eval("
          def #{name}_end
            :pop
          end")
    end

    def qualify_element(name)
      "element:#{qualify(name)}"
    end

    def qualify_type(name)
      "type:#{qualify(name)}"
    end

    def xmlns(ns)
      parent ? parent.xmlns(ns) : nil
    end

    def json_schema(name)
      parent ? parent.json_schema(ns) : nil
    end

    private

    def qualify(name)
      ns = if i = name.rindex(':')
             xmlns(name[0..i-1])
           else
             xmlns(:default)
           end
      if ns.blank? then
        name
      else
        "#{ns}:#{i ? name.from(i+1) : name}"
      end
    end
  end
end