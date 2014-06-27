module Hub
	class Variant
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps
	  
    embeds_many :options, class_name: 'Hub::Option'
	  embeds_many :images, class_name: 'Hub::Image'
    embedded_in :product, class_name: 'Hub::Product'

	  accepts_nested_attributes_for :options
	  accepts_nested_attributes_for :images

	  field :sku, type: String
	  field :price, type: Float
	  field :cost_price, type: Float	  
	  field :quantity, type: Integer

    validates_presence_of :sku
    validates_uniqueness_of :sku

	end
end
