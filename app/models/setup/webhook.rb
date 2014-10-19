module Setup
  class Webhook < Base
    include Setup::Enum

    field :name, type: String
    field :path, type: String
    field :purpose, type: String
    field :partial, type: String
    

    belongs_to :model, class_name: 'Setup::ModelSchema'
    belongs_to :connection, class_name: 'Setup::Connection', inverse_of: :webhooks
    
    scope :by_connection, lambda { |connection| where(connection: connection) }

    validates_presence_of :name, :path, :connection, :model
  
    rails_admin do
      
      field :name
      field :purpose
      field :connection
      field :model
      field :path
      field :partial do
        help 'optional partial schema for add params, validations, etc '
      end

      configure :model do
        associated_collection_scope do
          #Setup::ModelSchema.after_save_callback
          Webhook = bindings[:object]
          proc { Setup::ModelSchema.where(after_save_callback: true) }
        end
      end
      
      object_label_method do
        :full_name
      end

    end
    
    def full_name
      "#{connection.name} #{name}"
    end  

  end
end
