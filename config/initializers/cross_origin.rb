CrossOrigin.config :shared
CrossOrigin.config :admin
CrossOrigin.config :owner, collection: ->(model) do
  user = Cenit::MultiTenancy.tenant_model.current_tenant.owner
  "user#{user.id}_#{model.mongoid_root_class.storage_options_defaults[:collection]}"
end
CrossOrigin.config :cenit
CrossOrigin.config :tmp
CrossOrigin.config :app, collection: ->(_) do
  Cenit::MultiTenancy.tenant_model.tenant_collection_name(Setup::Application)
end