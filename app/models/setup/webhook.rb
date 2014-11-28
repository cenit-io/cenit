module Setup
  class Webhook
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped

    include Setup::Enum

    field :name, type: String
    field :path, type: String
    field :purpose, type: String

    belongs_to :data_type, class_name: Setup::DataType.name
    belongs_to :connection, class_name: Setup::Connection.name, inverse_of: :webhooks

    validates_presence_of :name, :path, :purpose
    
    rails_admin do
      edit do
        fields :name, :purpose, :connection, :path
      end
      list do
        fields :name, :purpose, :connection, :path
      end  
      show do
        field :_id
        field :created_at
        field :updated_at
        field :name
        field :purpose
        field :connection
        field :path
      end 
    end

  end
end
