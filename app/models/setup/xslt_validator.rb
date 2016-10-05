module Setup
  class XsltValidator < CustomValidator
    include SnippetCode
    include CustomTitle

    legacy_code_attribute :xslt

    build_in_data_type.referenced_by(:namespace, :name)

    field :schema_type, type: Symbol

    def code_extension
      '.xsl'
    end

    def validate_data(data)
      begin
        Nokogiri::XSLT(code).transform(Nokogiri::XML(data))
        []
      rescue  Exception => ex
        [ex.message]
      end
    end

  end
end
