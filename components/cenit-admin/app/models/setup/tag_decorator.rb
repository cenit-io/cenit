module Setup
  Tag.class_eval do
    include RailsAdmin::Models::Setup::TagAdmin
  end
end
