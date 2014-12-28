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
          def end_#{name.gsub(':', '_')}
            :pop
          end")
    end
  end
end