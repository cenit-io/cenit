module Setup
  class Resource
    include ShareWithBindingsAndParameters
    include NamespaceNamed
    include WithTemplateParameters
    include JsonMetadata
    include RailsAdmin::Models::Setup::ResourceAdmin

    build_in_data_type.referenced_by(:name, :namespace)

    field :path, type: String
    field :description, type: String

    parameters :parameters, :headers, :template_parameters

    has_many :operations, class_name: Setup::Operation.to_s, inverse_of: :resource, dependent: :destroy

    accepts_nested_attributes_for :operations, allow_destroy: true

    validates_presence_of :path

    def conformed_path(options = {})
      conform_field_value(:path, options)
    end

    def respond_to?(*args)
      super || Setup::Operation.method_enum.any? do |method|
        method == args[0] || args[0].to_s == "#{method}!"
      end
    end

    def method_missing(symbol, *args, &block)
      method = Setup::Operation.method_enum.detect do |method|
        method == symbol || symbol.to_s == "#{method}!"
      end
      if method && (operation = operations.where(method: method).first)
        submit_method = 'submit'
        if symbol.to_s.ends_with?('!')
          submit_method = "#{submit_method}!"
        end
        operation.send(submit_method, *args, &block)
      else
        super
      end
    end

  end
end
