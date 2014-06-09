module Hub
	class OrderTotal
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  belongs_to :order, class_name: 'Hub::Order'

	  field :adjustment, type: Float
    field :tax, type: Float
	  field :shipping, type: Float
    field :payment, type: Float
    field :order, type: Float

	  index({ starred: 1 })
	end
end
