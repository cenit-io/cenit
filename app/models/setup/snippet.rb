module Setup
  class Snippet
    include SharedEditable
    include NamespaceNamed

    build_in_data_type.referenced_by(:namespace, :name)

    field :description, type: String
    field :code, type: String

  end
end