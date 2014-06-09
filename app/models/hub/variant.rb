module Hub
	class Variant
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps
	  
    embeds_many :options, class_name: 'Hub::Option'
	  has_many :images, class_name: 'Hub::Image'
    belongs_to :product, class_name: 'Hub::Product'

    has_many :line_items,class_name: 'Hub::LineItem', inverse_of: :variant
    has_many :stock_items, class_name: 'Hub::Inventory', inverse_of: :variant

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
