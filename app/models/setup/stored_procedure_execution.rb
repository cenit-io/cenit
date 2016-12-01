module Setup
  class StoredProcedureExecution < Setup::Task

    build_in_data_type

    belongs_to :stored_procedure, :class_name => 'Setup::StoredProcedure', inverse_of: nil

    before_save do
      self.stored_procedure = Setup::StoredProcedure.where(id: message[:stored_procedure_id]).first
    end

    def run(message)
      stored_procedure = Setup::StoredProcedure.find(message[:stored_procedure_id])

      result = stored_procedure.run(message[:input])
      result = (result.is_a?(Hash) || result.is_a?(Array)) ? JSON.pretty_generate(result) : result.to_s

      attachment = result.present? ? {
        filename: "#{stored_procedure.name.collectionize}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.txt",
        contentType: 'text/plain',
        body: result
      } : nil

      notify(
        message: "'#{stored_procedure.custom_title}' result" + (result.present? ? '' : ' was empty'),
        type: :notice,
        attachment: attachment,
        skip_notification_level: message[:skip_notification_level]
      )
    end
  end

end
