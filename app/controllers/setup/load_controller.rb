module Setup
  class LoadController < Setup::BaseController

    def consume	  
      helper = Cenit::Loader.new(params.to_json)
      responder = helper.process
      render json: responder, root: false, status: responder.code
    rescue Exception => e
      puts "ERROR: #{e.inspect}"
    end

  end
end
