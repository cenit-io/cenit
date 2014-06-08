module Hub
	class Dimension
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embedded_in :image

	  field :height, type: Integer
	  field :width, type: Integer
	  index({ starred: 1 })
	end
end
