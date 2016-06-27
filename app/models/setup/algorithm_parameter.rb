module Setup
  class AlgorithmParameter
    include CenitScoped

    build_in_data_type.referenced_by(:name)

    field :name, type: String
    field :description, type: String

    embedded_in :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: :parameters

    validates_presence_of :name, :description
  end
end