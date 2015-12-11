module Setup
  class Webhook
    include CenitScoped
    include NamespaceNamed
    include ParametersCommon
    include AuthorizationHandler

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:connection_roles)

    embeds_many :parameters, class_name: Setup::Parameter.to_s, inverse_of: :webhook
    embeds_many :headers, class_name: Setup::Parameter.to_s, inverse_of: :webhook

    embeds_many :template_parameters, class_name: Setup::Parameter.to_s, inverse_of: :webhook

    field :path, type: String
    field :method, type: String, default: :post

    def method_enum
      [:get, :post, :put, :delete, :patch, :copy, :head, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]
    end

    validates_presence_of :path

    accepts_nested_attributes_for :parameters, :headers, :template_parameters, allow_destroy: true

    def conformed_path(options = {})
      conform_field_value(:path, options)
    end
  end
end
