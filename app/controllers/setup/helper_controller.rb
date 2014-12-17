module Setup
  class HelperController < Setup::BaseController

    def consume	  
      helper = Cenit::Helper.new(params.to_json)
      responder = helper.process
      render json: responder, root: false, status: responder.code
    rescue Exception => e
      puts "ERROR: #{e.inspect}"
    end

  end
end
