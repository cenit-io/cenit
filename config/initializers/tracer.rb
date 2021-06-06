Mongoid::Tracer.configure do |config|
  # config.trace_actions :create, :update, :delete
  #
  # config.trace_ignore :created_at, :updated_at

  config.author_id do
    ::User.current_id
  end
end