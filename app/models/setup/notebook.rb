module Setup
  class Notebook
    include CenitScoped
    include Mongoid::Timestamps

    build_in_data_type

    field :name, type: String
    field :gist_id, type: String

  end
end
