module Hub
  class Inventory
    include Mongoid::Document
    include Mongoid::Timestamps
    include Hub::AfterSave

    field :id, type: String
    field :location, type: String
    field :quantity, type: Integer
    field :product_id, type: String

    validates_presence_of :location, :quantity

  end
end
