module Hub
	class Inventory
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

    belongs_to :variant, class_name: "Hub::Variant", inverse_of: :stock_items
    belongs_to :product, class_name: "Hub::Product", inverse_of: :stock_items

	  field :_id, type: String
	  field :location, type: String
	  field :quantity, type: Integer

    #TODO: create am index product_id
    belongs_to :product, class_name: 'Hub::Product'

    validates_presence_of :location, :quantity 


	end
end
