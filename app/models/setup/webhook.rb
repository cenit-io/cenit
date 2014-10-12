module Setup
  class Webhook < Base
    include Setup::Enum

    field :name, type: String
    field :path, type: String

    belongs_to :model, class_name: 'Setup::ModelSchema'

    validates_presence_of :name, :path
  
    rails_admin do
      
      field :name
      field :path
      field :model

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
