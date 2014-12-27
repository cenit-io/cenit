[RailsAdmin::Config::Actions::SendToFlow,
 RailsAdmin::Config::Actions::TestTransformation,
 RailsAdmin::Config::Actions::LoadModel,
 RailsAdmin::Config::Actions::ShutdownModel,
 RailsAdmin::Config::Actions::SwitchNavigation,
 RailsAdmin::Config::Actions::DataType,
 RailsAdmin::Config::Actions::Import].each { |a| RailsAdmin::Config::Actions.register(a) }

RailsAdmin.config do |config|

  ### Popular gems integration

  ## == Devise ==
  # config.authenticate_with do
  #   warden.authenticate! scope: :user
  # end
  # config.current_user_method(&:current_user)

  ## == Cancan ==
  # config.authorize_with :cancan

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  config.excluded_models << "Account"

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method { current_user } # auto-generated
  config.audit_with :mongoid_audit

  config.actions do
    dashboard # mandatory
    index # mandatory
    new { except Setup::DataType,Role  }
    import
    #import do
    #  only 'Setup::DataType'
    #end
    export
    bulk_delete { except Setup::DataType,Role  }
    show
    edit { except Setup::Library,Role  }
    delete { except Setup::DataType,Role  }
    #show_in_app
    send_to_flow
    test_transformation
    load_model
    shutdown_model
    switch_navigation
    data_type

    history_index do 
      only [Setup::DataType,Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection,Setup::ConnectionRole, Setup::Notification, Setup::Library]
    end  
    history_show do 
      only [Setup::DataType,Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection,Setup::ConnectionRole, Setup::Notification, Setup::Library]
    end
  end
  
  config.model Setup::Webhook.name  do
    configure :path, :string do
      help "Requiered. Path of the webhook relative to connection URL."
      html_attributes do
       { maxlength: 50, size: 50 }
      end
    end

    show do
      field :name
      field :path
      field :purpose
      field :connection_roles
      field :schema_validation
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :name, :path, :purpose, :connection_roles, :schema_validation
  end
  
  config.model Setup::Schedule.name do
    visible false
    field :value
    field :period, :enum do 
      default_value 'minutes'
    end
  end
  
  config.model Setup::Batch.name do
    visible false
    field :size
  end
  
  config.model Setup::Connection.name do
    group :credentials do
      label "Token"
    end
    
    configure :connection_roles do
      inverse_of :connections
    end
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
        { maxlength: 30, size: 30 } 
      end
    end 
    configure :url, :string do
      help 'Requiered.'
      html_attributes do
        { maxlength: 50, size: 50 } 
      end
    end
    configure :key, :string do
      visible { bindings[:view]._current_user.has_role? :admin }
      html_attributes do
        { maxlength: 30, size: 30 } 
      end
    end
    configure :authentication_token, :text do
      visible { bindings[:view]._current_user.has_role? :admin }
      html_attributes do
        { cols: '50', rows: '1' }
      end
    end
    configure :connection_parameters do
      visible { bindings[:view]._current_user.has_role? :admin }
    end
    
    field :name
    field :url
    field :key do
      group :credentials
    end
    field :authentication_token do
      group :credentials
    end
    field :connection_roles
    field :connection_parameters
  end  
  
  config.model Setup::ConnectionParameter.name do
    visible false
    
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
       { maxlength: 50,size: 50 } 
      end
    end
    
    configure :value, :string do
      help 'Requiered.'
      html_attributes do
       { maxlength: 50,size: 50 }
      end
    end  

    fields :name, :value
  end
  
  config.model Setup::ConnectionRole.name do
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
       { maxlength: 50,size: 50 } 
      end
    end
    
    modal do
      field :name
      #field :connections
      field :webhooks
    end
    show do
      field :name
      field :connections
      field :webhooks
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :name, :connections, :webhooks
  end
   
  config.model Setup::DataType.name do
    group :model_definition do
      label 'Model definition'
      active true
    end
    
    group :sample_data do
      label 'Sample data'
      active do
        !bindings[:object].errors.get(:sample_data).blank?
      end
      visible do
        bindings[:object].is_object
      end
    end
    
    configure :uri do
      group :model_definition
      read_only true
      help ''
    end

    configure :name do
      group :model_definition
      read_only true
      help ''
    end

    configure :schema, :text do
      group :model_definition
      read_only true
      help ''
      html_attributes do
        { cols: '50', rows: '15' }
      end
    end

    configure :sample_data, :text do
      group :sample_data
      html_attributes do
        { cols: '70', rows: '15' }
      end
    end
    
    list do
      fields :uri, :name, :activated
    end    
    
    show do
      field :uri
      field :name
      field :activated
      field :schema
      field :sample_data
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :uri, :name, :activated, :schema, :sample_data
  end
  
  
  
  config.model Setup::Event.name do
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
       { maxlength: 50,size: 50 }
      end
    end
    
    configure :data_type do
      help false
      inline_add false
      inline_edit false
      associated_collection_cache_all false
      associated_collection_scope do
        Proc.new { |scope|
          scope = scope.where(activated: true)
        }
      end
    end
    
    configure :triggers do
      partial 'form_triggers'
      help false
    end

    show do
      field :name
      field :data_type

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    
    edit do
      fields :name, :data_type, :triggers
    end
    
    fields :name, :data_type
  end
  
  
  config.model Setup::Flow.name do
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
       { maxlength: 50,size: 50 }
      end
    end
    
    group :transformation do
      label 'Data transformation'
      active true
    end
    
    group :batching do
      label 'Batching'
    end
    
    configure :transformation do
      group :transformation
      partial 'form_transformation'
    end
    
    configure :schedule do
      group :batching
    end
    
    configure :batch do
      group :batching
    end
    
    edit do
      fields :name, :active, :purpose, :data_type, :connection_role, :webhook, :event, :schedule, :batch
    end
    
    show do
      field :name
      field :purpose
      field :data_type
      field :connection_role
      field :webhook
      field :event
      field :schedule
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater     
    end
    
    fields :name, :active, :purpose, :event, :connection, :connection_role, :webhook, :schedule
  end
  
  config.model Setup::Library.name do
    configure :name do
      read_only { !bindings[:object].new_record? }
      help ''
    end
    
    show do
      field :name
      field :schemas
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater 
    end
    
    fields :name, :schemas
  end
  
  config.model Setup::Notification.name do
    show do
      field :flow
      field :http_status_code
      field :count
      field :http_status_message
      field :json_data
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater 
    end
    fields :flow, :http_status_code, :count, :http_status_message, :json_data
  end
  
  config.model Setup::Schema.name do
    object_label_method do
      :uri
    end
    
    configure :library do
      read_only { !bindings[:object].new_record? }
      inline_edit false
    end
    
    configure :uri do
      read_only { !bindings[:object].new_record? }
    end
    
    configure :schema, :text do
      html_attributes do
        { cols: '74', rows: '15' }
      end
    end
    
    show do
      field :library
      field :uri
      field :schema
      field :data_types
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater 
    end
    fields :library, :uri, :data_types, :schema

  end
  
end
