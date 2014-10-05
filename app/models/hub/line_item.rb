module Hub
  class LineItem < Hub::Base

    field :name, type: String
    field :quantity, type: Integer
    field :price, type: Float
    field :product_id, type: String

    embedded_in :order, class_name: 'Hub::Order'
    embedded_in :shipment, class_name: 'Hub::Shipment'
    embedded_in :cart, class_name: 'Hub::Cart'

    validates_presence_of  :name, :quantity, :price

  end
end
