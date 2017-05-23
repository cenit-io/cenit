module Cenit
  class Responder
    attr_accessor :request_id, :summary, :code

    def initialize(request_id, summary)
      self.request_id = request_id
      self.summary =
        case summary
        when Exception
          Setup::SystemReport.create_from(summary)
          self.code = 406
          "#{summary.class.to_s.split('::').collect(&:to_title).join('. ')}: #{summary.message}"
        when :unauthorized
          self.code = 401
          'Not authorized'
        else
          self.code = 200
          summary.to_s
        end
    end

  end
end
