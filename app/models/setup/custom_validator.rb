module Setup
  class CustomValidator < Validator
    include CrossOriginShared

    abstract_class true

    build_in_data_type.referenced_by(:namespace, :name)
  end
end
