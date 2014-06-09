module Hub
	class Product
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  has_many :variants, class_name: 'Hub::Variant'
	  has_many :images, class_name: 'Hub::Image'
    has_many :inventory, class_name: 'Hub::Inventory'

    embeds_many :taxons, class_name: 'Hub::Taxon'
    embeds_many :properties, class_name: 'Hub::Property'
	  
	  accepts_nested_attributes_for :variants
	  accepts_nested_attributes_for :images
    accepts_nested_attributes_for :properties
    accepts_nested_attributes_for :taxons    

	  field :_id, type: String
	  field :name, type: String
	  field :sku, type: String
	  field :description, type: String 
	  field :price, type: Float
	  field :cost_price, type: Float
	  field :available_on, type: Date 
	  field :permalink, type: String
	  field :meta_description, type: String
	  field :meta_keywords, type: String
	  field :shipping_category, type: String
	  field :options, type: Array

    validates_presence_of :id, :name, :sku, :price, :available_on 
    validates_uniqueness_of :sku

    validates_numericality_of :price, { greater_than: 0 }

	  # TODO: pass these methods to an external module and later use it as include
	  after_create do |object|
		path = 'add_' + object.class.to_s.downcase.split('::').last
		Cenit::Middleware::Producer.process(object, path, false)
	  end
	  
	  after_update do |object|
		path = 'update_' + object.class.to_s.downcase.split('::').last
		Cenit::Middleware::Producer.process(object, path, true)
	  end

	end
end
