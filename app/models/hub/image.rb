module Hub
	class Image
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embeds_one :dimensions

	  accepts_nested_attributes_for :dimensions,  :autosave => true

	  field :url, type: String
	  field :position, type: String
	  field :title, type: String

	  index({ starred: 1 })
	end
end
