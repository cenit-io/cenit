module Hub
	class Image
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps
       
    belongs_to :variant, class_name: 'Hub::Variant'
    belongs_to :product, class_name: 'Hub::Product'

	  embeds_one :dimension, class_name: 'Hub::Dimension'

	  accepts_nested_attributes_for :dimension

	  field :url, type: String
	  field :position, type: String
	  field :title, type: String
    field :type, type: String

    validates_presence_of :url

	end
end
