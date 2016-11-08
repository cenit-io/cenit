module Setup
  class Resource
    include ShareWithBindingsAndParameters
    include NamespaceNamed
    include WithTemplateParameters
    
    field :section, type: String

    field :path, type: String
    field :description, type: String

    parameters :template_parameters

    has_many :operations, class_name: Setup::Webhook.to_s, inverse_of: :resource
    
    validates_presence_of :path

    def conformed_path(options = {})
      conform_field_value(:path, options)
    end
  end
end
