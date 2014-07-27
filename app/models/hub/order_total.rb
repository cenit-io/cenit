module Hub
  class OrderTotal
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Mongoid::Timestamps

    embedded_in :order, class_name: 'Hub::Order'

    field :adjustment, type: Float
    field :tax, type: Float
    field :shipping, type: Float
    field :payment, type: Float
    field :order, type: Float
    field :item, type: Float

    validates :adjustment, :tax, :shipping, :payment, :order, :item, numericality: {greater_than_or_equal_to: 0}

  end
end
