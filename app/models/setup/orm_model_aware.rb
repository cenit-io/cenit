module Setup
  module OrmModelAware

    def orm_model
      self.class
    end

  end
end