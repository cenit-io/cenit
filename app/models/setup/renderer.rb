module Setup
  class Renderer < LegacyTranslator
    transformation_type :Export

    build_in_data_type.with(:namespace, :name, :source_data_type, :style, :bulk_source, :mime_type, :file_extension, :snippet ).referenced_by(:namespace, :name)
  end
end
