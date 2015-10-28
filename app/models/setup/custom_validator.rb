module Setup
  class CustomValidator < Validator
    include CenitScoped

    BuildInDataType.regist(self).referenced_by(:namespace, :name)
    
  end
end