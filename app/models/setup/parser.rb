module Setup
  class Parser < LegacyTranslator

    transformation_type :Import

    build_in_data_type.with(:namespace, :name, :target_data_type, :discard_events, :style, :snippet).referenced_by(:namespace, :name)

    build_in_data_type.and(abstract: true)
  end
end
