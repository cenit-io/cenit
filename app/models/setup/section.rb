module Setup
  class Section
    include CenitScoped
    include NamespaceNamed
    include JsonMetadata
    include RailsAdmin::Models::Setup::SectionAdmin

    belongs_to :connection, class_name: Setup::Connection.to_s, inverse_of: :nil
    has_many :resources, class_name: Setup::Resource.to_s, inverse_of: :nil
    has_many :representations, class_name: Setup::Representation.to_s, inverse_of: :nil

    field :description, type: String
  end
end
