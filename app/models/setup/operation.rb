module Setup
  class Operation < Webhook
    include RailsAdmin::Models::Setup::OperationAdmin
    build_in_data_type.including(:resource).referenced_by(:resource, :method)

    deny :all
    allow :show, :edit, :delete

    belongs_to :resource, class_name: Setup::Resource.to_s, inverse_of: :operations

    trace_ignore :resource_id

    field :description, type: String
    field :method, type: String

    parameters :parameters, :headers

    # trace_references :parameters, :headers

    validates_presence_of :resource, :method

    def tracing?
      false
    end

    def params_stack
      super.insert(-2, resource)
    end

    def scope_title
      resource && resource.custom_title
    end

    def namespace
      (resource && resource.namespace) || ''
    end

    def path
      resource && resource.path
    end

    def template_parameters
      (resource && resource.template_parameters) || []
    end

    def namespace_enum
      (resource && resource.namespace_enum) || []
    end

    def name
      "#{method.to_s.upcase} #{resource && resource.custom_title}"
    end

    def label
      "#{method.to_s.upcase}"
    end

    def title
      label
    end

    def connections
      (resource && resource.connections).presence || super
    end

    protected

    def conforms(field, template_parameters = {}, base_hash = nil)
      if resource
        base_hash = resource.conforms(field, template_parameters, base_hash)
      end
      super
    end

  end
end
