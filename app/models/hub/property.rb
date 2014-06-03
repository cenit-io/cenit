module Hub
	class Property
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  has_and_belongs_to_many :products
	  field :name, type: String
	  field :presentation, type: String
	  index({ starred: 1 })
	end
end
