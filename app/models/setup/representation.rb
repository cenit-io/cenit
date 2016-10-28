module Setup
  class Representation
    include CenitScoped
    include NamespaceNamed
    include JsonMetadata

    belongs_to :section, class_name: Setup::Section.to_s, inverse_of: :nil
    field :description, type: String
  end
end
