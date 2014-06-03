module Setup
	class Connection
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  field :name, type: String
	  field :url, type: String
	  
	  has_and_belongs_to_many :webhooks, :class_name => "Setup::Webhook"
	  
	  index({ starred: 1 })
	end
end
