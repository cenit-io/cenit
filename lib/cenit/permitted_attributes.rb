module Cenit
  module PermittedAttributes
    ATTRIBUTES = [
      :connection_attributes,
      :connection_role_attributes,
      :webhook_attributes,
      :flow_attributes,
      :schema_attributes, 
      :validator_attributes,
      :event_attributes,
      :library_attributes,
      :collection_attributes,
      :traslator_attributes,
      :parameter_attributes,
      :scheduler_attributes,
      :observer_attributes,
      :notification_attributes,
    ]

    mattr_reader *ATTRIBUTES

    @@connection_attributes = [
      :id, :name, :url, :key, :token, :number
    ]

    @@connection_role_attributes = [
      :id, :name
    ]

    @@webhook_attributes = [
      :id, :name, :path, :purpose, :method
    ]

    @@flow_attributes = [
      :id, :name, :purpose, :active, :data_type_id, :connection_role_id, :webhook_id, :event_id, :traslator_id, :lot_size, :discard_events
    ]
    
    @@schema_attributes = [
      :id, :uri, :schema
    ]
    
    @@validator_attributes = [
      :id, :name, :style, :schema_id
    ]
    
    @@event_attributes = [
      :id, :name
    ]
    
    @@library_attributes = [
      :id, :name
    ]
    
    @@collection_attributes = [
      :id, :name
    ]
    
    @@traslator_attributes = [
      :id, :name, :type, :style, :mime_type, :file_extension, :bulk_source, :transformation, :discard_chained_records
    ]
    
    @@parameter_attributes = [
      :id, :key, :value
    ]
    
    @@scheduler_attributes = [
      :id, :name, :scheduling_method, :expression
    ]
    
    @@observer_attributes = [
      :id, :triggers
    ]
    
    @@notification_attributes = [
      :id, :response, :message, :exception_message
    ]
    
  end
end