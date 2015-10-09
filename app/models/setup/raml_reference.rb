module Setup
  class RamlReference
    include CenitUnscoped

    BuildInDataType.regist(self).with(:path, :content)

    field :path, type: String
    field :content, type: String

    embedded_in :raml, class_name: Setup::Raml.to_s

    validates_presence_of :path, :content

    def to_s
      path.to_s
    end

  end
end