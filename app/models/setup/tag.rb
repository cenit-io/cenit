module Setup
  class Tag
    include SharedEditable
    include NamespaceNamed
    include ::RailsAdmin::Models::Setup::TagAdmin

  end
end
