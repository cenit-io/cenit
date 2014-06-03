module Hub
	class Variant
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  has_and_belongs_to_many :options
	  embeds_many :images

	  accepts_nested_attributes_for :images,  :autosave => true
	  accepts_nested_attributes_for :options,  :autosave => true

	  field :sku, type: String
	  field :price, type: Float
	  field :cost_price, type: Float
	  
	  field :quantity, type: Integer
	  field :images, type: String

	  index({ starred: 1 })
	end
end
