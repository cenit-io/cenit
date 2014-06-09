module Hub
	class Cart
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  field :_id, type: String
    field :status, type: String
    field :channel, type: String
    field :email, type: String
    field :currency, type: String
    field :placed_on, type: Date

	  has_one :totals, class_name: 'Hub::OrderTotal'

    has_many :line_items, class_name: 'Hub::LineItem'
    embeds_many :adjustments, class_name: 'Hub::Adjustment'
    
    embeds_many :payments, class_name: 'Hub::Payment'
    has_many :shipments, class_name: 'Hub::Shipment'

    belongs_to :shipping_address, class_name: 'Hub::Address'
    belongs_to :billing_address, class_name: 'Hub::Address'

	  accepts_nested_attributes_for :totals
	  accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :adjustments
    accepts_nested_attributes_for :shipping_address 
    accepts_nested_attributes_for :billing_address   
    accepts_nested_attributes_for :payments 
    accepts_nested_attributes_for :shipments 

    validates_presence_of :id, :status, :channel, :email, :currency, 
      :placed_on, :shipping_address, :billing_address

	  index({ starred: 1 })
	end
end
