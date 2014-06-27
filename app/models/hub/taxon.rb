module Hub
	class Taxon
	  include Mongoid::Document
	  #include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  embedded_in :product, class_name: 'Hub::Product'
	  field :breadcrumb, type: Array

	end
end
