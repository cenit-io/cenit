[RailsAdmin::Config::Actions::SendToFlow,
 RailsAdmin::Config::Actions::TestTransformation,
 RailsAdmin::Config::Actions::LoadModel,
 RailsAdmin::Config::Actions::ShutdownModel,
 RailsAdmin::Config::Actions::SwitchNavigation,
 RailsAdmin::Config::Actions::DataType,
 RailsAdmin::Config::Actions::Import,
 RailsAdmin::Config::Actions::EdiExport,
 RailsAdmin::Config::Actions::ImportSchema,
 RailsAdmin::Config::Actions::DeleteAll,
 RailsAdmin::Config::Actions::NewTranslator,
 RailsAdmin::Config::Actions::EditTranslator,
 RailsAdmin::Config::Actions::Update,
 RailsAdmin::Config::Actions::Convert].each { |a| RailsAdmin::Config::Actions.register(a) }

RailsAdmin.config do |config|

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  config.excluded_models << ["Account", "Setup::Parameter"].flatten

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method { current_user }
  config.audit_with :mongoid_audit
  config.authorize_with :cancan
  
  config.actions do
    dashboard # mandatory
    index # mandatory
    new { except [Setup::DataType, Role, Setup::Translator]  }
    new_translator
    import
    import_schema
    update
    convert
    #import do
    #  only 'Setup::DataType'
    #end
    export
    bulk_delete { except [Setup::DataType, Role]  }
    show
    edit { except [Setup::Library, Setup::DataType, Role, Setup::Translator]  }
    edit_translator
    edi_export
    delete { except [Setup::DataType, Role]  }
    #show_in_app
    send_to_flow
    test_transformation
    load_model
    shutdown_model
    switch_navigation
    data_type

    history_index do 
      only [Setup::DataType,Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection,Setup::ConnectionRole, Setup::Library]
    end  
    history_show do 
      only [Setup::DataType,Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection,Setup::ConnectionRole, Setup::Notification, Setup::Library]
    end
    delete_all { except Setup::DataType,Role  }
  end
  
  config.model Role.name  do
    weight -20
    navigation_label 'Account'
    show do
      field :name
      field :user
      
      field :_id
    end
    fields :name, :users
  end
  
  config.model Setup::Library.name do
    navigation_label 'Data Definitions'
    weight -19
    
    configure :name do
      read_only { !bindings[:object].new_record? }
      help ''
    end

    edit do
      field :name
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
  
    fields :name,:schemas
  end

  config.model Setup::Schema.name do
    navigation_label 'Data Definitions'
    weight -18
      
    object_label_method {:uri}
  
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
    fields :library, :uri, :schema
  end

  config.model Setup::DataType.name do
    navigation_label 'Data Definitions'
    weight -17
          
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
  
  config.model Setup::Template.name do
    navigation_label 'Setup'
    weight -16
    configure :webhooks do
      nested_form false
    end
    configure :flows do
      nested_form false
    end
    show do
      field :name
      field :library
      field :connection_role
      field :webhooks
      field :flows
    
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater 
    end
    fields :name, :library, :connection_role, :webhooks, :flows
  end
  
  config.model Setup::Connection.name do
    weight -15
    group :credentials do
      label "Credentials"
    end
    configure :connection_roles do
      nested_form false
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
      group :credentials
    end
    configure :token, :text do
      visible { bindings[:view]._current_user.has_role? :admin }
      html_attributes do
        { cols: '50', rows: '1' }
      end
      group :credentials
    end
    configure :url_parameters do
      visible { bindings[:view]._current_user.has_role? :admin }
    end
    configure :headers do
      visible { bindings[:view]._current_user.has_role? :admin }
    end
    
    group :parameters do
      label "Add Parameters"
    end
    configure :url_parameters do
      group :parameters
    end  
    configure :headers do
      group :parameters
    end  
    
    show do
      field :name
      field :url
      field :connection_roles

      field :key
      field :token
      
      field :url_parameters
      field :headers
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    
      fields :name, :url, :connection_roles, :url_parameters, :headers, :key, :token
  end
  
  config.model Setup::Parameter.name do
    visible false
  end

  config.model Setup::UrlParameter.name do
    object_label_method do
      :to_s
    end
    configure :key, :string do
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
    
    show do
      field :key
      field :value
      field :parameterizable
      
      field :_id
      field :created_at
      field :updated_at
    end
    
    list do
      field :key
      field :value
      field :parameterizable
    end

    fields :key, :value
  end
  
  config.model Setup::Header.name do
    object_label_method do
      :to_s
    end
    configure :key, :string do
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
    
    show do
      field :key
      field :value
      field :parameterizable
      
      field :_id
      field :created_at
      field :updated_at
    end
    
    list do
      field :key
      field :value
      field :parameterizable
    end

    fields :key, :value
  end
  
  config.model Setup::ConnectionRole.name do
    weight -14
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
       { maxlength: 50,size: 50 } 
      end
    end
    configure :webhooks do
      nested_form false
    end
    configure :connections do
      nested_form false
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
  
  config.model Setup::Webhook.name do
    weight -13
    
    group :request do
      label 'Resquest'
    end
    
    group :response do
      label 'Response'
    end
    
    configure :path, :string do
      help "Requiered. Path of the webhook relative to connection URL."
      html_attributes do
       { maxlength: 50, size: 50 }
      end
    end
    configure :connection_roles do
      nested_form false
    end
    configure :schema_validation do
      help "Optional. Validate transformed flow document using this schema."
      group :request
    end
    configure :data_type do
      help "Optional. Save document as an object of this 'data-type'."
      group :request
    end
    configure :trigger_event do
      help "Optional. Trigger events after save the object."
      group :request
    end
    
    configure :schema_validation_response do
      help "Optional. Validate response document using this schema."
      group :response
    end
    configure :data_type_response do
      help "Optional. Save document as an object of this 'data-type'."
      group :response
    end
    configure :trigger_event_response do
      help "Optional. Trigger events after save the object."
      group :response
    end
    
    group :parameters do
      label "Add Parameters"
    end
    configure :url_parameters do
      group :parameters
    end  
    configure  :headers do
      group :parameters
    end

    show do
      field :name
      field :purpose
      field :path
      field :method
      field :connection_roles
      field :flow
      
      field :url_parameters
      field :headers
      
      #request
      field :schema_validation
      field :data_type
      field :trigger_event
      
      #response
      field :schema_validation_response
      field :data_type_response
      field :trigger_event_response
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :name, :purpose, :path, :method,:connection_roles, :url_parameters, :headers, :schema_validation, :data_type, :trigger_event,  :schema_validation_response, 
    :data_type_response, :trigger_event_response
  end
  
  
  config.model Setup::Event.name do
    weight -12
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
    weight -11
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
       { maxlength: 50,size: 50 }
      end
    end
    
    group :batching do
      label 'Schedule & Batch'
    end
    
    group :transformation do
      label 'Data transformation'
      active true
    end
    
    configure :schedule do
      group :batching
    end
    
    configure :batch do
      group :batching
    end
    
    configure :style, :enum do
      group :transformation
    end
    
    configure :transformation do
      group :transformation
      partial 'form_transformation'
    end
    
    edit do
      fields :name, :active, :purpose, :data_type, :connection_role, :webhook, :event, :schedule, :batch, :style, :transformation
    end
    
    show do
      field :name
      field :purpose
      field :data_type
      field :connection_role
      field :webhook
      field :event
      field :schedule
      field :style
      field :transformation
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater     
    end
    
    fields :name, :active, :purpose, :event, :connection_role, :webhook, :schedule
  end
  
  config.model Setup::Schedule.name do
    parent Setup::Flow
    configure :period, :enum do 
      default_value 'minutes'
    end
    
    object_label_method do
      :frequency
    end
    
    show do
      field :flow
      field :value
      field :period
      field :active
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :flow, :value, :period, :active
  end
  
  config.model Setup::Batch.name do
    parent Setup::Flow
    show do
      field :flow
      field :size
      field :schedule
      field :batch
      
      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    
    fields :flow, :size
  end
  
  config.model Setup::Notification.name do
    weight -10
    navigation_label 'Notifications'
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
  
  config.model Setup::Transform.name do
    weight -9

    configure :data_type do
      inline_add false
      inline_edit false
    end

    configure :schema_validation do
      inline_add false
      inline_edit false
    end

    configure :transformation do
      group :transformation
      partial 'form_transformation'
    end
    
    configure :style, :enum do
      group :transformation
    end
    
    show do
      field :name
      field :data_type
      field :schema_validation
      field :flow
      field :style
      field :transformation

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :name, :data_type, :schema_validation, :style, :transformation
  end

end
