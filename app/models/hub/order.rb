module Hub
  class Order
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Mongoid::Timestamps
    #include Hub::AfterSave

    belongs_to :connection, class_name: 'Setup::Connection'

    field :id, type: String
    field :status, type: String
    field :channel, type: String
    field :email, type: String
    field :currency, type: String
    field :placed_on, type: Date

    embeds_one :totals, class_name: 'Hub::OrderTotal'

    belongs_to :shipping_address, class_name: 'Hub::Address'
    belongs_to :billing_address, class_name: 'Hub::Address'

    embeds_many :line_items, class_name: 'Hub::LineItem'
    embeds_many :adjustments, class_name: 'Hub::Adjustment'
    embeds_many :payments, class_name: 'Hub::Payment'

    accepts_nested_attributes_for :totals
    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :adjustments
    accepts_nested_attributes_for :shipping_address
    accepts_nested_attributes_for :billing_address
    accepts_nested_attributes_for :payments

    validates_presence_of :id, :status, :channel, :currency, :placed_on

  end
end
