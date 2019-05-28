module Setup
  class WebHookNotification < Setup::Notification
    include Setup::TranslationCommon::ClassMethods

    transformation_types Setup::Template.concrete_class_hierarchy

    field :url, type: String
    field :http_method, type: Symbol, default: :GET
    field :template_options, type: String

    def validates_configuration
      self.template_options = template_options.to_s.strip
      if super && !requires(:url, :http_method)
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
      errors.blank?
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
      Setup::Connection.send(http_method.to_s.downcase, url).submit(msg)
    end

    class << self
      def http_method_enum
        [:GET, :POST, :PUSH, :DELETE]
      end
    end
  end
end
