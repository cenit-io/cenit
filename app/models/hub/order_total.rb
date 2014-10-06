module Hub
  class OrderTotal < Hub::Base

    field :adjustment, type: Float
    field :tax, type: Float
    field :shipping, type: Float
    field :payment, type: Float
    field :order, type: Float
    field :item, type: Float

    embedded_in :sale_order, class_name: 'Hub::Order'
    embedded_in :cart, class_name: 'Hub::Cart'

    validates :order, :item, numericality: { greater_than: -1 }

  end
end
