module Setup
  class XsltValidator < CustomValidator
    include CenitScoped
    include CustomTitle

    BuildInDataType.regist(self).with(:namespace).referenced_by(:namespace)

    field :xslt, type: String

    field :schema_type, type: Symbol

    def before_save
      errors.blank?
    end

    def validate_data(data)
      xslt = Nokogiri::XSLT(self.xslt)
      begin
        xslt.transform(Nokogiri::XML(data.to_xml()))
        validate = true
      rescue  Exception => ex
        ex.message
      end
    end

  end
end
