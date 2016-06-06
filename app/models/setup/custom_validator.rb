module Setup
  class CustomValidator < Validator
    include CenitScoped

    build_in_data_type.referenced_by(:namespace, :name)
    
  end
end