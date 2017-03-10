module Setup
  class Converter < Translator
    include RailsAdmin::Models::Setup::ConverterAdmin
    transformation_type :Conversion
    allow :new
    build_in_data_type.with(:namespace, :name, :source_data_type, :target_data_type,
                            :discard_events, :style, :source_handler, :snippet, :source_exporter,
                            :target_importer, :discard_chained_records).referenced_by(:namespace, :name)
  end
end
