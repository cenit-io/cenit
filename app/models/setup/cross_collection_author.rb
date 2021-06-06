module Setup
  class CrossCollectionAuthor
    include ReqRejValidator
    include CenitUnscoped

    build_in_data_type.referenced_by(:email)

    field :name, type: String
    field :email, type: String

    embedded_in :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: :authors

    validates_presence_of :email
    validates_length_of :name, maximum: 255

    def label
      "#{name} (#{email})"
    end

  end
end
