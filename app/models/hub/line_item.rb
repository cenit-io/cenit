module Hub
	class LineItem
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  field :name, type: String
    field :quantity, type: Integer
    field :price, type: Float

	  belongs_to :order, class_name: 'Hub::Order'
	  belongs_to :cart, class_name: 'Hub::Cart'
    belongs_to :shipment, class_name: 'Hub::Shipment'

    belongs_to :variant, class_name: 'Hub::Variant'
    belongs_to :product, class_name: 'Hub::Product'

    has_many :options, class_name: "Hub::Option"
    accepts_nested_attributes_for :options



    validates_presence_of  :name, :quantity, :price

	end
end
