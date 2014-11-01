module Setup
  class Webhook < Base
    include Setup::Enum

    belongs_to :model, class_name: Setup::ModelSchema.name
    belongs_to :connection, class_name: Setup::Connection.name, inverse_of: :webhooks
    has_many :flows, class_name: Setup::Flow.name, inverse_of: :webhook

    field :name, type: String
    field :path, type: String
    field :purpose, type: String
    field :partial, type: String
    
    accepts_nested_attributes_for :flows
    
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
          Webhook = bindings[:object]
          proc { Setup::ModelSchema.where(after_save_callback: true) }
        end
      end
      
      object_label_method do
        :full_name
      end
      
      field :flows
    end
    
    private
      def full_name
        "#{connection.name} #{name}"
      end

  end
end
