module Setup
  module NamespaceNamed
    extend ActiveSupport::Concern

    include ::DynamicValidators
    include CustomTitle

    included do

      build_in_data_type.and_polymorphic(label: '{{namespace}} | {{name}}')

      field :namespace, type: String
      field :name, type: String

      validates_presence_of :name
      validates_uniqueness_of :name, scope: :namespace

      before_validation do
        self.namespace =
          if namespace.nil?
            ''
          else
            namespace.strip
          end
        self.name = name.to_s.strip
        # unless ::User.super_access?
        #   errors.add(:namespace, 'is reserved') if Cenit.reserved_namespaces.include?(namespace.downcase)
        # end TODO Implements reserved namespaces
        errors.blank?
      end

      after_save do
        Setup::Optimizer.regist_ns(namespace)
      end
    end

    def scope_title
      namespace
    end

    def ns_slug
      namespace_ns.slug
    end

    def namespace_ns
      if @namespace_ns.nil? || @namespace_ns.name != namespace
        @namespace_ns = Setup::Namespace.find_or_create_by(name: namespace)
      end
      @namespace_ns
    end

    def namespace_ns=(namespace_ns)
      @namespace_ns = namespace_ns
      self.namespace = namespace_ns.name if namespace != namespace_ns.name
    end

    module ClassMethods
      def namespace_enum
        (Setup::Namespace.all.collect(&:name) + all.distinct(:namespace).flatten).uniq.sort
      end
    end
  end
end
