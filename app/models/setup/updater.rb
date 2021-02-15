module Setup
  class Updater < LegacyTranslator
    # = Updater
    #
    # Updating data already stored.

    transformation_type :Update

    build_in_data_type.with(:namespace, :name, :target_data_type, :discard_events, :style, :source_handler, :snippet)
      .referenced_by(:namespace, :name)
      .and(abstract: true)
  end
end
