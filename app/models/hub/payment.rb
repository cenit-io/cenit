module Hub
	class Payment
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embedded_in :order, class_name: 'Hub::Order'

	  field :number, type: Integer
	  field :status, type: String
    field :amount, type: Float
    field :payment_method, type: String

    validates_presence_of :number, :status, :amount, :payment_method

	  index({ starred: 1 })
	end
end
