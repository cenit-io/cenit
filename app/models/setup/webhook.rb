module Setup
  class Webhook < Base
    include Setup::Enum

    field :name, type: String
    field :path, type: String
    field :purpose, type: String
    field :partial, type: String
    

    belongs_to :model, class_name: 'Setup::ModelSchema'
    belongs_to :connection, class_name: 'Setup::Connection', inverse_of: :webhooks
    
    scope :by_connection, -> { |connection| where(connection: connection) }

    validates_presence_of :name, :path
  
    rails_admin do
      
      field :name
      field :purpose
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

    end

  end
end
