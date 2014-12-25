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
      only [Setup::DataType,Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::Notification, Setup::Library]
    end  
    history_show do 
      only [Setup::DataType,Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::Notification, Setup::Library]
    end
  end
  
  config.model Setup::Webhook.name  do
    edit do
      fields :name, :purpose, :connection, :path
    end
    create do
      fields :name, :purpose, :connection, :path
    end
    update do
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
    nested do
      field :name, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 50,size: 50 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end
      field :purpose
      field :path, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 50,size: 50 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end
    end
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
    edit do
      field :name, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 30,size: 30 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end 
      field :url, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 50,size: 50 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end 
      field :key do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :authentication_token do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :connection_parameters do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :webhooks
    end
    
    create do
      group :credentials do
        label "Token"
      end
      field :name, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 25,size: 25 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end 
      field :url, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 50,size: 50 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end 
      field :key do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
        group :credentials
      end
      field :authentication_token, :string do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
        html_attributes do
         { maxlength: 50,size: 50 } #dont use 600 as maxlength for a string field. It will break the UI
        end
        group :credentials
      end
      
      field :connection_parameters do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :webhooks
    end
    list do
      field :name 
      field :url
      field :key do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :authentication_token do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :connection_parameters do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :webhooks
    end
    
    show do
      field :_id
      field :created_at
      field :updated_at
      field :name 
      field :url
      field :key do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :authentication_token do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :connection_parameters do
        visible do
          bindings[:view]._current_user.has_role? :admin
        end
      end
      field :webhooks
    end   
  end
  
  config.model Setup::ConnectionParameter.name do
    visible false
    create do
      field :name
      field :value, :string
    end
    modal do
      field :name
      field :value, :string
    end
    nested do
      field :name, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 50,size: 50 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end  
      field :value, :string do
        help 'Requiered'
        html_attributes do
         { maxlength: 50,size: 50 } #dont use 600 as maxlength for a string field. It will break the UI
        end
      end
    end
    
  end
   
  config.model Setup::DataType.name do
    show do
      field :_id
      field :created_at
      field :updated_at
      field :name
      field :activated
      field :schema
      field :sample_data
    end
    
    edit do
      group :model_definition do
        label 'Model definition'
        active true
      end

      field :uri do
        group :model_definition
        read_only true
        help ''
      end

      field :name do
        group :model_definition
        read_only true
        help ''
      end

      field :schema do
        group :model_definition
        read_only true
        help ''
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

      field :sample_data do
        group :sample_data
      end
    end
    
    list do
      fields :uri, :name, :activated
    end

    show do
      fields :uri, :name, :activated, :schema, :sample_data
    end
  end
  
  
  
  config.model Setup::Event.name do
    list do
      fields :name, :data_type
    end
    show do
      field :_id
      field :created_at
      field :updated_at
      field :name
      field :data_type
    end
    edit do
      field :name
      field :data_type do
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
      field :triggers do
        partial 'form_triggers'
        help false
      end
    end

  end
  
  
  config.model Setup::Flow.name  do
    edit do
      field :name
      field :active
      field :purpose
      field :data_type
      field :connection
      field :webhook
      field :event
      
      group :batching do
        label 'Batching'
      end
      field :schedule do
        group :batching
      end
      field :batch do
        group :batching
      end

      group :transformation do
        label 'Data transformation'
        active true
      end
      field :transformation do
        group :transformation
        partial 'form_transformation'
      end
    end
    
    list do
      fields :name, :active, :purpose, :event, :connection, :webhook, :schedule
    end
    
    show do
      field :_id
      field :updated_at
      field :created_at
      field :name
      field :purpose
      field :data_type
      field :connection
      field :webhook
      field :event
      field :schedule
    end
  end
  

  config.model Setup::Library.name do
    edit do
      field :name do
        read_only { !bindings[:object].new_record? }
        help ''
      end
      field :schemas
    end
    list do
      field :name
      field :schemas
    end
    show do
      field :_id
      field :created_at
      field :updated_at
      field :name
      field :schemas
    end
    
  end
  
  config.model Setup::Notification.name do
    edit do
      field :flow
      field :http_status_code
      field :count
      field :http_status_message
      field :json_data
    end
    list do
      field :updated_at
      field :flow
      field :http_status_code
      field :count
      field :http_status_message
    end  
    show do
      field :_id
      field :created_at
      field :updated_at
      field :flow
      field :http_status_code
      field :count
      field :http_status_message
      field :json_data
    end 
  end
  
  config.model Setup::Schema.name do
    object_label_method do
      :uri
    end
    edit do
      field :library do
        read_only { !bindings[:object].new_record? }
        inline_edit false
      end
      field :uri do
        read_only { !bindings[:object].new_record? }
      end
      field :schema
    end
    list do
      fields :library, :uri, :schema, :data_types
    end
  end
  
end
