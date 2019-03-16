module Setup
  module BuildIn
    def tracing?
      origin != :cenit
    end

    def share_hash(options = {})
      if origin == :cenit
        options[:reference] = true
      end
      super
    end
  end
end
