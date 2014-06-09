module Hub
	class Inventory
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  field :_id, type: String
	  field :location, type: String
	  field :quantity, type: Integer

    #TODO: create am index product_id
    belongs_to :product, class_name: 'Hub::Product', index: true

    validates_presence_of :location, :product, :quantity 

	end
end
