module Hub
	class Source
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embedded_in :payment, class_name: 'Hub::Payment'

	  field :name, type: String
	  field :month, type: Integer
    field :year, type: Integer
    field :cc_type, type: String
    field :last_digits, type: Integer

    validates_presence_of :name, :cc_type

	end
end
