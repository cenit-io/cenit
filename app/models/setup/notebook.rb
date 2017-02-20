module Setup
  class Notebook
    include CrossOriginShared
    include RailsAdmin::Models::Setup::NotebookAdmin

    build_in_data_type.with(:module, :name, :content, :shared, :writable, :origin, :created_at, :updated_at)

    field :module, type: String
    field :name, type: String
    field :content, type: String
    field :shared, type: Boolean
    field :writable, type: Boolean
    field :created_at, type: DateTime
    field :updated_at, type: DateTime

    attr_readonly :writable, :shared

    def shared
      self.origin != :default
    end

    def origin=(v)
      cross(v) if v != self.origin && !self.new_record?
    end

    def writable
      self.tenant == Account.current
    end

    def path
      "#{self.module}/#{self.name}"
    end

  end
end
