module Setup
  module CenitReservedNamespace
    extend ActiveSupport::Concern

    include Setup::NamespaceNamed

    included do

      validates_presence_of :namespace

      before_save do
        unless User.current.super_admin?
          errors.add(:namespace, 'is reserved') if Cenit.reserved_namespaces.include?(namespace.downcase)
        end
        errors.blank?
      end
    end
  end
end