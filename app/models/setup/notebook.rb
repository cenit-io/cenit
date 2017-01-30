module Setup
  class Notebook
    include CenitScoped
    include Mongoid::Timestamps

    build_in_data_type

    field :name, type: String
    field :parent, type: String
    field :type, type: String
    field :content, type: String
    field :format, type: String
    field :mimetype, type: String
    field :writable, type: Boolean

    def type_enum
      %w(notebook file directory)
    end
  end
end
