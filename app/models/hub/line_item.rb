module Hub
	class LineItem
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  belongs_to :order, class_name: 'Hub::Order'
	  belongs_to :cart, class_name: 'Hub::Cart'

    belongs_to :variant, class_name: 'Hub::Variant', inverse_of: :line_items
    belongs_to :product, class_name: 'Hub::Product', inverse_of: :line_items

	  field :product_id, type: String
	  field :name, type: String
    field :quantity, type: Integer
    field :price, type: Float

    validates_presence_of  :name, :quantity, :price

	end
end
