module Setup
	class Notification
	  include Mongoid::Document
	  include Mongoid::Attributes::Dynamic
	  include Mongoid::Timestamps

	  belongs_to :connection
	  belongs_to :webhook
	  field :status, type: String
	  
	  index({ starred: 1 })
	end
end
