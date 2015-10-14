module Setup
  class CollectionAuthor < ReqRejValidator
    include CenitUnscoped

    BuildInDataType.regist(self)

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
