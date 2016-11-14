module Setup
  class Operation
    include ShareWithBindingsAndParameters
    include WithTemplateParameters

    build_in_data_type.referenced_by(:resource, :method)

    deny :all
    allow :show, :edit, :delete

    belongs_to :resource, class_name: Setup::Resource.to_s, inverse_of: :operations

    field :description, type: String
    field :method, type: String, default: :post

    parameters :parameters, :headers

    validates_presence_of :resource, :method

    def template_parameters
      (resource && resource.template_parameters) || []
    end

    def label
      "#{method.to_s.upcase}"
    end

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
