module Xsd
  class BasicTag

    attr_reader :parent, :annotation

    def initialize(args)
      @parent = args[:parent]
      self.class.instance_methods.each do |method|
        if method =~ /\Ainitialize(\_[a-z]+)+\Z/
          send(method, args)
        end
      end
    end

    def when_annotation_end(annotation)
      @annotation = annotation
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

    def included?(qualified_name, visited = Set.new)
      parent ? parent.included?(qualified_name, visited) : false
    end

    def qualify_element(name)
      qualify_with(:element, name)
    end

    def qualify_type(name)
      qualify_with(:type, name)
    end

    def qualify_attribute_group(name)
      qualify_with(:attribute_group, name)
    end

    def qualify_attribute(name)
      qualify_with(:attribute, name)
    end

    def xmlns(ns)
      parent ? parent.xmlns(ns) : nil
    end

    def documenting(obj)
      if obj.is_a?(Hash) && annotation && !(docs = annotation.documentations).empty?
        obj['description'] =
          if docs.size == 1
            docs[0].to_description
          else
            "<ul>\n" + docs.collect { |doc| "<li>\n" + doc.to_description + "\n</li>" }.join("\n") + '</ul>'
          end
      end
      obj
    end

    protected

    def qualify_with(qualify_method, name, check_include = true)
      check_include && included?(qn = "#{name_prefix}#{qualify_method}:#{name}") ? qn : "#{name_prefix}#{qualify_method}:#{qualify(name)}"
    end

    def qualify(name)
      ns = (i = name.rindex(':')) ? xmlns(name[0..i-1]) : xmlns(:default)
      if ns.blank?
        name
      else
        "#{ns}:#{i ? name.from(i+1) : name}"
      end
    end
  end
end