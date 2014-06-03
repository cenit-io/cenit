module Hub
	class Product
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  #embeds_many :variants
	  #embeds_many :images
	  
	  #accepts_nested_attributes_for :variants,  :autosave => true
	  #accepts_nested_attributes_for :images,  :autosave => true

	  field :_id, type: String
	  field :name, type: String #, require: true
	  field :sku, type: String #, require: true
	  field :description, type: String #, require: true
	  field :price, type: Float #, require: true
	  field :cost_price, type: Float
	  field :available_on, type: Date #, require: true
	  field :permalink, type: String
	  field :meta_description, type: String
	  field :meta_keywords, type: String
	  field :shipping_category, type: String
	  field :options, type: Array

	  index({ starred: 1 })

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
