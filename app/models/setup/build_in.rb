module Setup
  module BuildIn

    def share_hash(options = {})
      if origin == :cenit
        options[:reference] = true
      end
      super
    end
  end
end
