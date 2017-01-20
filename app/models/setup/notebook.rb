module Setup
  class Notebook
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, type: String
    field :gist_id, type: String

  end
end
