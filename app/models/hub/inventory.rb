module Hub
  class Inventory < Hub::Base

    include Hub::AfterSave

    field :id, type: String
    field :location, type: String
    field :quantity, type: Integer
    field :product_id, type: String

    validates_presence_of :location, :quantity

  end
end
