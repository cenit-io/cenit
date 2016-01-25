module Setup
  module NamespaceNamed
    extend ActiveSupport::Concern

    include DynamicValidators
    include CustomTitle

    included do
      field :namespace, type: String
      field :name, type: String, default: ''

      validates_presence_of :name
      validates_length_in_presence_of :namespace, maximum: 255
      validates_uniqueness_of :name, scope: :namespace

      before_save do
        self.namespace =
          if namespace.nil?
            ''
          else
            namespace.strip
          end
        self.name = name.to_s.strip
        # unless Account.current.super_admin?
        #   errors.add(:namespace, 'is reserved') if Cenit.reserved_namespaces.include?(namespace.downcase)
        # end TODO Delete comment
        errors.blank?
      end
    end

    def scope_title
      namespace
    end
  end
end