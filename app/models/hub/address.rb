module Hub
	class Address
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embedded_in :order, class_name: 'Hub::Order'

	  field :firstname, type: String
	  field :lastname, type: String
	  field :address1, type: String
	  field :address2, type: String
	  field :city, type: String
	  field :state, type: String
	  field :country, type: String
	  field :phone, type: String

    validates_presence_of :firstname, :lastname, :address1,:address2,
          :city,:state,:country

	  index({ starred: 1 })
	end
end
