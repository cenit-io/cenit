module Setup
  class EdiValidator < CustomValidator
    include CenitScoped
    include Setup::FormatValidator

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    belongs_to :schema_data_type, class_name: Setup::SchemaDataType.to_s, inverse_of: nil

    field :content_type, type: String

    # field :infers_field_separtor, type:  Boolean
    # field :field_separator, type: String
    # field :segment_separator, type: String

    validates_presence_of :schema

    def content_type
      self[:content_type]
    end

    def content_type_enum
      MIME::Types.inject([]) { |types, t| types << t.to_s }
    end

    def data_format
      :edi
    end

    def format_options
      {} #TODO edi options
    end

    def validate_file_record(file)
      begin
        Edi::Parser.parse_edi(data_type, file.data, format_options)
        []
      rescue Exception => ex
        [ex.message]
      end
    end
  end
end