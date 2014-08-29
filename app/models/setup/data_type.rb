module Setup
  class DataType
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, type: String
    field :klass, type: String

    validates_presence_of :name

  end
end
