module Setup
  module BuildIn

    def tracing?
      false
    end

    def share_hash(options = {})
      if origin == :cenit
        options[:reference] = true
      end
      super
    end
  end
end
