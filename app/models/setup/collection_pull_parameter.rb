module Setup
  class CollectionPullParameter
    include CenitUnscoped

    BuildInDataType.regist(self)

    field :label, type: String
    field :parameter, type: String

    embedded_in :shared_collection, class_name: Setup::SharedCollection.to_s, inverse_of: :parameters

    validates_presence_of :label, :parameter
    validates_length_of :label, maximum: 255
  end
end
