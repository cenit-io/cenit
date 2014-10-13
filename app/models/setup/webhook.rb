module Setup
  class Webhook < Base
    include Setup::Enum

    field :name, type: String
    field :path, type: String
    field :purpose, type: String

    belongs_to :model, class_name: 'Setup::ModelSchema'
    has_many :connection_webhooks, class_name: 'Setup::ConnectionWebhook', inverse_of: :connection

    validates_presence_of :name, :path
  
    rails_admin do
      
      field :name
      field :path
      field :model
      field :purpose

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
