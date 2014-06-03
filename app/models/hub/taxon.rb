module Hub
	class Taxon
	  has_and_belongs_to_many :products
	  field :name, type: String
	  index({ starred: 1 })
	end
end
