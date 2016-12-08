module Setup
  class Parser < Translator
    include RailsAdmin::Models::Setup::ParserAdmin

    transformation_type :Import
    allow :new

    build_in_data_type.with(:namespace, :name, :target_data_type, :discard_events, :style, :snippet).referenced_by(:namespace, :name)

  end
end
