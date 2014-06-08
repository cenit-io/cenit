module Hub
	class Property
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embedded_in :product, class_name: 'Hub::Product'

	  field :name, type: String
	  field :presentation, type: String

	  index({ starred: 1 })
	end
end
