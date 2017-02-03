module Setup
  class Notebook
    include CenitScoped
    include Mongoid::Timestamps

    build_in_data_type.with(:module, :name, :content, :created_at, :updated_at)

    field :module, type: String
    field :name, type: String
    field :content, type: String
    field :created_at, type: DateTime
    field :updated_at, type: DateTime

    def type_enum
      %w(notebook file directory)
    end

  end
end
