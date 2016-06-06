module Setup
  class Parameter
    include CenitScoped
    include JsonMetadata

    build_in_data_type.with(:key, :value, :description, :metadata).referenced_by(:key)

    field :key, type: String, as: :name
    field :value, type: String, default: ''
    field :description, type: String

    validates_presence_of :key
    
    def to_s
      "#{key}: #{value}"
    end
  end 
end
