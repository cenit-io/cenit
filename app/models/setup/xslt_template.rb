module Setup
  class XsltTemplate < Template
    include SnippetCodeTemplate
    include XsltTemplateCommon
    include RailsAdmin::Models::Setup::XsltTemplateAdmin

    build_in_data_type.referenced_by(:namespace, :name)

    def validates_configuration
      method = output_method
      if %w(xml html text).include?(method)
        if mime_type.present?
          unless mime_type[method]
            errors.add(:mime_type, "is not compatible with transformation method '#{method}'")
          end
        else
          self.mime_type =
            case method
            when 'xml'
              'application/xml'
            when 'html'
              'text/html'
            when 'text'
              'text/plain'
            else
              nil
            end
        end
      else
        errors.add(:code, "defines a non supported output method: #{method}")
      end
      super
    end

    def mime_type_enum
      %w(application/xml text/html text/plain)
    end

    def execute(options)
      code = options[:code] || self.code
      render(code, options[:source].to_xml)
    end

    def ready_to_save?
      true
    end

    def can_be_restarted?
      false
    end
  end
end
