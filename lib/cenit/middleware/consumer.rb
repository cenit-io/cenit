require 'json'
require 'openssl'
require 'httparty'


module Cenit
  module Middleware
	  class Consumer

	    # TODO: create a noitfication from response
	    def self.process(message)
		    message = JSON.parse(message)
		    response = HTTParty.post(message['url'],
	      	  {
	        		body: message['object'].to_json,
	        		headers: {
	          		 'Content-Type'       => 'application/json',
	          		 'X-Hub-Store'        => '123',
	          		 'X-Hub-Access-Token' => '456',
	          		 'X-Hub-Timestamp'    => Time.now.utc.to_i.to_s
          		}
	      	  }
	      	)
	    end

	  end
  end
end
