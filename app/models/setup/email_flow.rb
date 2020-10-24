module Setup
  class EmailFlow < EmailChannel
    include CenitScoped

    build_in_data_type.referenced_by(:namespace, :name, :_type)

    belongs_to :send_flow, class_name: Setup::Flow.to_s, inverse_of: nil

    def send_message(message)
      send_flow && send_flow.process(source_id: message.id.to_s)
    end
  end
end
