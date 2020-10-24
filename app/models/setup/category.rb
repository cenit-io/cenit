module Setup
  class Category
    include CenitUnscoped

    build_in_data_type.and(
      properties: {
        id: {
          type: 'string',
          edi: { segment: 'id' }
        }
      }
    )

    deny :all
    allow :index, :show, :simple_export, :export

    field :_id, type: String
    field :title, type: String
    field :description, type: String

    validates_length_of :_id, :title, maximum: 100
    validates_presence_of :_id, :title
  end
end
