module Setup
  class WebHookNotification < Setup::NotificationFlow
    include Setup::TranslationCommon::ClassMethods

    HOOK_METHODS = %w(GET POST PUSH DELETE).map(&:to_sym)

    build_in_data_type.and(
      properties: {
        hook_method: {
          enum: HOOK_METHODS.map(&:to_s)
        }
      }
    )

    transformation_types Setup::Template

    field :url, type: String
    field :hook_method, type: StringifiedSymbol, default: :POST
    field :template_options, type: String

    validates_inclusion_of :hook_method, in: HOOK_METHODS

    def validates_configuration
      super
      self.template_options = template_options.to_s.strip
      unless requires(:url, :hook_method)
        if template_options.present?
          begin
            parse_options(template_options)
          rescue Exception => ex
            errors.add(:template_options, "syntax error: #{ex.message}")
          end
        else
          remove_attribute(:template_options)
        end
      end
      abort_if_has_errors
    end

    def process(record)
      options = { options: parse_options(template_options) }
      if transformation.bulk_source
        options[:sources] = [record]
      else
        options[:source] = record
      end
      data = transformation.run(options)
      msg = { body: data, template_parameters: record.to_hash }
      if (mime_type = transformation.mime_type)
        msg[:contentType] = mime_type
      end
      Setup::Connection.send(hook_method.to_s.downcase, url).submit(msg)
    end
  end
end
