module Hub
  class Shipment
    include Mongoid::Document
    include Mongoid::Timestamps
    include Hub::AfterSave

    field :id, type: String
    field :order_id, type: String
    field :email, type: String
    field :cost, type: Float
    field :status, type: String
    field :stock_location, type: String
    field :shipping_method, type: String
    field :tracking, type: String
    field :shipped_at, type: Date
    field :updated_at, type: Date
    field :channel, type: String

    embeds_many :items, class_name: 'Hub::LineItem'
    embeds_one :shipping_address, class_name: 'Hub::Address'

    accepts_nested_attributes_for :items
    accepts_nested_attributes_for :shipping_address

  end
end
