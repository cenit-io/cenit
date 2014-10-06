module Hub
  class Cart < Hub::Base
    
    include Hub::AfterSave
    
    field :id, type: String
    field :status, type: String
    field :channel, type: String
    field :email, type: String
    field :currency, type: String
    field :placed_on, type: Date

    embeds_one :totals, class_name: 'Hub::OrderTotal'
    embeds_one :shipping_address, class_name: 'Hub::Address'
    embeds_one :billing_address, class_name: 'Hub::Address'

    embeds_many :line_items, class_name: 'Hub::LineItem'
    embeds_many :adjustments, class_name: 'Hub::Adjustment'
    embeds_many :payments, class_name: 'Hub::Payment'

    accepts_nested_attributes_for :totals
    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :adjustments
    accepts_nested_attributes_for :shipping_address
    accepts_nested_attributes_for :billing_address
    accepts_nested_attributes_for :payments

    validates_presence_of :id, :status, :channel, :email, :currency,
    :placed_on, :shipping_address, :billing_address

  end
end
