module Setup
  class Operation
    include ShareWithBindingsAndParameters
    include NamespaceNamed
    include WithTemplateParameters

    field :method, type: String, default: :post
    field :description, type: String
    
    belongs_to :resource, class_name: Setup::Resource.to_s, inverse_of: :nil

    parameters :parameters, :headers, :template_parameters

    def method_enum
      self.class.method_enum
    end

    class << self
      def method_enum
        [:get, :post, :put, :delete, :patch, :copy, :head, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]
      end
    end
    
  end
end
