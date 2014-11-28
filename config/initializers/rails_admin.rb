[RailsAdmin::Config::Actions::SendToFlow,
 RailsAdmin::Config::Actions::TestTransformation].each { |a| RailsAdmin::Config::Actions.register(a) }

[RailsAdmin::Config::Actions::New,
RailsAdmin::Config::Actions::Delete,
RailsAdmin::Config::Actions::BulkDelete].each do |action|
action.register_instance_option :visible? do
   !bindings[:abstract_model].model_name.eql?(Setup::DataType.to_s)
end
end

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

  config.actions do
    dashboard # mandatory
    index # mandatory
    new
    import do
      only 'Setup::DataType'
    end
    export
    bulk_delete
    show
    edit
    delete
    show_in_app
    send_to_flow
    test_transformation

    ## With an audit adapters, you can add:
    # history_index
    # history_show
  end
end
