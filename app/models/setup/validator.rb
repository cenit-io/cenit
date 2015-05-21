module Setup
  class Validator
    include CenitScoped

    Setup::Models.exclude_actions_for self, :bulk_delete, :delete, :delete_all

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