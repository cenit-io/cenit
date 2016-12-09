module ContactUs
  class << self
    def config(&block)
      if block_given?
        block.call(ContactUs::Config)
      else
        ContactUs::Config
      end
    end
    def require_name

    end
    def require_subject

    end
  end
  module Config
    class << self
      attr_accessor :mailer_from
      attr_accessor :mailer_to
      attr_accessor :require_name
      attr_accessor :require_subject
      attr_accessor :form_gem
      attr_accessor :success_redirect
    end
  end
end