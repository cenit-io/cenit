module Hub
	class Property
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embedded_in :product, class_name: 'Hub::Product'

	  field :name, type: String
	  field :presentation, type: String

    validates_presence_of :name, :presentation

	  index({ starred: 1 })
	end
end
