module Setup
  class EmailNotification < Setup::Notification

    transformation_types Setup::Template.concrete_class_hierarchy, Setup::ConverterTransformation.concrete_class_hierarchy

    belongs_to :email_channel, class_name: Setup::EmailChannel.to_s, inverse_of: nil

    def validates_configuration
      if super && !requires(:email_channel)
        if transformation.is_a?(Setup::Converter)
          if email_data_type
            unless transformation.target_data_type.eql?(email_data_type)
              errors.add(:transformation, "wrong target data type, expected to be #{email_data_type.custom_title}")
            end
          else
            errors.add(:transformation, 'of type converter can not be used since the email data type is not yet configured')
          end
        end
      end
      abort_if_has_errors
    end

    def process(record)
      fail 'Email data type not yet configured' unless email_data_type

      message = transformation.run(source: record, discard_events: true)
      unless message.is_a?(email_data_type.records_model)
        message =
          case message
          when Hash
            email_data_type.create_from_json!(message, discard_events: true)
          else
            email_data_type.create_from!(message.to_s, discard_events: true)
          end
      end

      email_channel.send_message(message)
    end

    def email_data_type
      self.class.email_data_type
    end

    class << self

      def email_data_type
        Setup::Configuration.email_data_type
      end

      def email_data_type_id
        Setup::Configuration.email_data_type_id
      end
    end
  end
end
