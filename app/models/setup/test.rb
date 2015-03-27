module Setup
  class Test
    include CenitScoped

    BuildInDataType.regist(self).with(:name)

    field :name, type: String

    mount_uploader :asset, AvatarUploader
  end 
end
