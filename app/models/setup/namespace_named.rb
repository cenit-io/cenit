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
        if namespace.nil?
          self.namespace = ''
        else
          self.namespace = namespace.strip
        end
        self.name = name.to_s.strip
      end
    end

    def scope_title
      namespace
    end
  end
end