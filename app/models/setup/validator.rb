module Setup
  class Validator
    include CenitScoped

    field :name, type: String

    validates_uniqueness_of :name

    before_save :validates_configuration

    def validates_configuration
      errors.blank?
    end

    def validate_data(data)
      fail NotImplementedError
    end

    def content_type
      nil
    end
  end
end