module Setup
  class EdiValidator < CustomValidator
    include CenitScoped
    include DataTypeValidator

    BuildInDataType.regist(self).referenced_by(:name)

    belongs_to :schema, class_name: Setup::Schema.to_s, inverse_of: nil

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

    def data_type
      schema.data_type
    end

    def data_format
      :edi
    end

    def format_options
      {} #TODO edi options
    end

    def validate_data(data)
      begin
        Edi::Parser.parse_edi(data_type, data, format_options)
        []
      rescue Exception => ex
        [ex.message]
      end
    end
  end
end