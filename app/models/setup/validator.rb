module Setup
  class Validator
    include CenitScoped
    include NamespaceNamed
    include ClassHierarchyAware
    include SharedEditable
    include ::RailsAdmin::Models::Setup::ValidatorAdmin

    abstract_class true

    build_in_data_type.referenced_by(:namespace, :name)

    before_save :validates_configuration

    def validates_configuration
      errors.blank?
    end

    def validate_data(_data)
      fail NotImplementedError
    end

    def validate_file_record(file)
      validate_data(file.data)
    end

    def data_format
      nil
    end

    def content_type
      nil
    end

  end
end
