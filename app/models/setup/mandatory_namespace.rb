module Setup
  module MandatoryNamespace
    extend ActiveSupport::Concern

    include Setup::NamespaceNamed

    included do
      validates_presence_of :namespace
    end
  end
end
