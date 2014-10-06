module Hub
  class Order < Hub::Base
    
    include Hub::AfterSave

    field :id, type: String
    field :status, type: String
    field :channel, type: String
    field :email, type: String
    field :currency, type: String
    field :placed_on, type: DateTime
    field :token, type: String
    field :shipping_instructions, type: String

    embeds_one :totals, class_name: 'Hub::OrderTotal'
    embeds_many :line_items, class_name: 'Hub::LineItem'
    embeds_many :adjustments, class_name: 'Hub::Adjustment'
    embeds_many :payments, class_name: 'Hub::Payment'

    embeds_one :shipping_address, class_name: 'Hub::Address'
    embeds_one :billing_address, class_name: 'Hub::Address'

    accepts_nested_attributes_for :totals
    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :adjustments
    accepts_nested_attributes_for :shipping_address
    accepts_nested_attributes_for :billing_address
    accepts_nested_attributes_for :payments

    validates_presence_of :id, :status, :channel, :currency, :placed_on

  end
end
