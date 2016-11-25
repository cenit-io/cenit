module Setup
  class Resource
    include ShareWithBindingsAndParameters
    include NamespaceNamed
    include WithTemplateParameters
    include JsonMetadata

    build_in_data_type.embedding(:operations).referenced_by(:name, :namespace)

    field :path, type: String
    field :description, type: String

    parameters :parameters, :headers, :template_parameters

    has_many :operations, class_name: Setup::Operation.to_s, inverse_of: :resource, dependent: :destroy

    accepts_nested_attributes_for :operations, allow_destroy: true

    validates_presence_of :path

    def conformed_path(options = {})
      conform_field_value(:path, options)
    end
  end
end
