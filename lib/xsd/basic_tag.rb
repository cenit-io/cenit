module Xsd
  class BasicTag

    attr_reader :parent

    def initialize(parent)
      @parent = parent
    end

    def document
      @document ||= (p = parent) ? p.document : nil
    end

    def tag_name
      self.class.try(:tag_name)
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

    def name_prefix
      parent ? parent.name_prefix : ''
    end

    def included?(qualified_name)
      parent ? parent.included?(qualified_name) : false
    end

    def qualify_element(name)
      included?(qn = "#{name_prefix}element:#{name}") ? qn : "#{name_prefix}element:#{qualify(name)}"
    end

    def qualify_type(name)
      included?(qn = "#{name_prefix}type:#{name}") ? qn : "#{name_prefix}type:#{qualify(name)}" if name
    end

    def xmlns(ns)
      parent ? parent.xmlns(ns) : nil
    end

    def json_schema(name)
      parent ? parent.json_schema(ns) : nil
    end

    private

    def qualify(name)
      ns = (i = name.rindex(':')) ? xmlns(name[0..i-1]) : xmlns(:default)
      ns.blank? ? name : "#{ns}:#{i ? name.from(i+1) : name}"
    end
  end
end