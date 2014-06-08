module Hub
	class Image
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embeds_one :dimension, class_name: 'Hub::Dimension'
    embedded_in :variant, class_name: 'Hub::Variant'
    embedded_in :product, class_name: 'Hub::Product'

	  accepts_nested_attributes_for :dimension

	  field :url, type: String
	  field :position, type: String
	  field :title, type: String
    field :type, type: String

	  index({ starred: 1 })
	end
end
