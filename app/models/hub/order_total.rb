module Hub
  class OrderTotal
    include Mongoid::Document
    include Mongoid::Timestamps

    field :adjustment, type: Float
    field :tax, type: Float
    field :shipping, type: Float
    field :payment, type: Float
    field :order, type: Float
    field :item, type: Float

    embedded_in :sale_order, class_name: 'Hub::Order'

    validates :adjustment, :tax, :shipping, :payment, :order, :item, numericality: {greater_than_or_equal_to: 0}

  end
end
