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

      before_save { self.namespace = '' if namespace.nil? }

    end

    def scope_title
      namespace
    end
  end
end