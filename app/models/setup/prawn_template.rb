module Setup
  class PrawnTemplate < Template
    include RubyCodeTemplate

    build_in_data_type.referenced_by(:namespace, :name)

    before_validation :ensure_pdf_content_type

    def save(options = {})
      ensure_pdf_content_type
      super
    end

    def mime_type_enum
      'application/pdf'
    end

    def ensure_pdf_content_type
      self.mime_type = 'application/pdf'
      self.file_extension = 'pdf'
    end

    def additional_local_variables
      { pdf: PrawnRails::Document.new }
    end

    def preprocess_code(code)
      "#{code}\npdf.render;"
    end
  end
end
