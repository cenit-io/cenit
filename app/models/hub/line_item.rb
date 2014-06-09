module Hub
	class LineItem
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  belongs_to :order, class_name: 'Hub::Order'
	  belongs_to :cart, class_name: 'Hub::Cart'

	  field :product_id, type: String
	  field :name, type: String
    field :quantity, type: Integer
    field :price, type: Float

    validates_presence_of :product_id, :name, :quantity, :price

	  index({ starred: 1 })
	end
end
