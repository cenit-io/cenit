module Setup
  class EmailNotification < Setup::NotificationFlow

    transformation_types Setup::Template, Setup::ConverterTransformation

    belongs_to :email_channel, class_name: Setup::EmailChannel.to_s, inverse_of: nil
    belongs_to :email_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    def validates_configuration
      if super && !requires(:email_channel, :email_data_type)
        if transformation.is_a?(Setup::Converter)
          unless transformation.source_data_type.eql?(data_type)
            errors.add(:transformation, "wrong source data type, expected to be #{data_type.custom_title}")
          end
          if email_data_type
            unless transformation.target_data_type.eql?(email_data_type)
              errors.add(:transformation, "wrong target data type, expected to be #{email_data_type.custom_title}")
            end
          else
            errors.add(:transformation, 'of type converter can not be used since the email data type is not configured')
          end
        end
      end
      abort_if_has_errors
    end

    def process(record)
      email_data_type = self.email_data_type || Setup::Configuration.singleton_record.email_data_type

      fail 'Email data type not configured' unless email_data_type

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
  end
end
