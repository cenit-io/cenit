module Setup
  class ConnectionParameter
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped

    belongs_to :connection, class_name: Setup::Connection.name, inverse_of: :connection_parameters

    devise :database_authenticatable

    field :name, type: String
    field :value, type: String

    validates_presence_of :name, :value
     
  end
end
