module Setup
  class CollectionAuthor
    include ReqRejValidator
    include CenitUnscoped
    include RailsAdmin::Models::Setup::CollectionAuthorAdmin

    build_in_data_type

    field :name, type: String
    field :email, type: String

    embedded_in :shared_collection, class_name: Setup::SharedCollection.to_s, inverse_of: :authors

    validates_presence_of :name, :email
    validates_length_of :name, maximum: 255
    validates_format_of :email, with: /\A[a-z]+@[a-z]+(\.[a-z]+)+\Z/i

    def label
      "#{name} (#{email})"
    end
  end
end
