module Hub
	class Address
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  field :firstname, type: String
	  field :lastname, type: String
	  field :address1, type: String
	  field :address2, type: String, default: ''
	  field :city, type: String
	  field :state, type: String
	  field :country, type: String
	  field :phone, type: String
    field :zipcode, type: String

    validates_presence_of :firstname, :lastname, :address1,:zipcode,
          :city,:state,:country

	end
end
