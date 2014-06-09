module Hub
	class Address
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

    belongs_to :customer, class_name: 'Hub::Customer'

	  field :firstname, type: String
	  field :lastname, type: String
	  field :address1, type: String
	  field :address2, type: String, default: ''
	  field :city, type: String
	  field :state, type: String
	  field :country, type: String
	  field :phone, type: String
    field :zipcode, type: String

    validates_presence_of :firstname, :lastname, :address1, :address2,
          :city,:state,:country

	end
end
