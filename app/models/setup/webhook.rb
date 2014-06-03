module Setup
	class Webhook
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  field :name, type: String
	  field :path, type: String
	  
	  has_and_belongs_to_many :connections, :class_name => "Setup::Connection"
	  	  
	  index({ starred: 1 })
	end
end
