module Setup
  class Webhook
    include CenitScoped
    include Setup::Enum
    include ParametersCommon

    BuildInDataType.regist(self).referenced_by(:name).excluding(:connection_roles)

    embeds_many :parameters, class_name: Setup::Parameter.to_s, inverse_of: :webhook
    embeds_many :headers, class_name: Setup::Parameter.to_s, inverse_of: :webhook

    embeds_many :template_parameters, class_name: Setup::Parameter.to_s, inverse_of: :webhook

    field :name, type: String
    field :path, type: String
    field :purpose, type: String, default: :send
    field :method, type: String, default: :post

    def method_enum
      [:get, :post, :put, :delete, :copy, :head, :patch, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]
    end

    validates_presence_of :name, :path, :purpose
    validates_uniqueness_of :name

    accepts_nested_attributes_for :parameters, :headers, :template_parameters, allow_destroy: true

    def conformed_path(options = {})
      conform_field_value(:path, options)
    end
  end
end
