[RailsAdmin::Config::Actions::SendToFlow,
 RailsAdmin::Config::Actions::TestTransformation].each { |a| RailsAdmin::Config::Actions.register(a) }

RailsAdmin.config do |config|

  ### Popular gems integration
  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0
  
  config.excluded_models << "Account" << "Role"

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  
  config.authorize_with :cancan
  config.current_user_method &:current_user

  config.actions do
    dashboard # mandatory
    index # mandatory
    new do
      except [Setup::DataType.to_s, 'Setup::Notification']
    end
    export
    bulk_delete do
      except [Setup::DataType.to_s]
    end  
    show
    edit
    delete do
      except [Setup::DataType.to_s]
    end
    send_to_flow
    test_transformation
    
    #import do
    #  only 'Setup::DataType'
    #end
    #show_in_app

    ## With an audit adapters, you can add:
    # history_index
    # history_show
  end
end
