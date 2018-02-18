module Setup
  class Translator
    include CrossOriginShared
    include NamespaceNamed
    include ClassHierarchyAware

    abstract_class true

    build_in_data_type.referenced_by(:namespace, :name)

    field :type, type: Symbol, default: -> { self.class.transformation_type }

    before_validation do
      if (type = self.class.transformation_type)
        self.type = type
      end
    end

    def data_type
      fail NotImplementedError
    end

    def run(options = {})
      fail NotImplementedError
    end

    class << self

      def type_enum
        [:Import, :Export, :Update, :Conversion]
      end

      def transformation_type(*args)
        if args.length > 0
          @transformation_type = args[0].to_s.to_sym
        end
        @transformation_type || (superclass < Translator ? superclass.transformation_type : nil)
      end
    end
  end
end
