module Hub
	class OrderTotal
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  field :adjustment, type: Float, default: 0
    field :tax, type: Float, default: 0
	  field :shipping, type: Float, default: 0
    field :payment, type: Float, default: 0
    field :order, type: Float, default: 0
    field :item, type: Float, default: 0

    validates :adjustment,:tax,:shipping,
              :payment,:order,:item, numericality: {
      greater_than_or_equal_to: 0
    }

	end
end
