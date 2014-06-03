
  module Cenit
    class Responder
      attr_accessor :request_id, :summary, :code, :backtrace, :objects

      def initialize(request_id, summary, code=200, objects=nil)
        self.request_id = request_id
        self.summary = summary
        self.code = code
        self.objects = objects
      end

    end
  end
