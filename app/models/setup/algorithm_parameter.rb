module Setup
  class AlgorithmParameter
    include CenitScoped

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: String
    field :description, type: String

    embedded_in :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: :parameters

    validates_presence_of :name, :description
  end
end