module Setup
  class Notebook
    include CenitUnscoped
    include Mongoid::Timestamps

    build_in_data_type.with(:module, :name, :content, :shared, :writable, :created_at, :updated_at)

    field :module, type: String
    field :name, type: String
    field :content, type: String
    field :shared, type: Boolean
    field :writable, type: Boolean
    field :created_at, type: DateTime
    field :updated_at, type: DateTime

    belongs_to :owner, class_name: Cenit::MultiTenancy.user_model_name, inverse_of: nil

    attr_readonly :owner, :writable

    set_callback :save, :before, :before_save

    default_scope -> {
      where(nil
      ).or(
        owner: Cenit::MultiTenancy.tenant_model.current ? Cenit::MultiTenancy.tenant_model.current.owner : nil
      ).or(
        shared: true
      )
    }

    def type_enum
      %w(notebook file directory)
    end

    def before_save
      self.shared = false if self.shared.nil?
      self.owner ||= Cenit::MultiTenancy.tenant_model.current.owner
    end

    def writable
      self.owner == Cenit::MultiTenancy.tenant_model.current.owner
    end

  end
end
