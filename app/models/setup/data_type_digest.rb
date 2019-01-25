module Setup
  class DataTypeDigest < Setup::Task
    include ::RailsAdmin::Models::Setup::DataTypeDigestAdmin

    build_in_data_type

    def data_type_id(msg = message)
      msg[:data_type_id] || msg['data_type_id']
    end

    def data_type(msg = message)
      Setup::DataType.where(id: data_type_id(msg)).first
    end

    def payload(msg = message)
      msg[:payload]  || msg['payload']
    end

    def options(msg = message)
      msg[:options] || msg['options'] || {}
    end

    def run(message)
      if (dt = data_type(message))
        dt.create_from!(payload(message), options(message))
      else
        fail "Data type with ID #{data_type_id(message)} not found"
      end
    end

    class << self
      def process(message = {}, &block)
        if (data_type = message.delete(:data_type))
          message[:data_type_id] = data_type.id
        end
        super(message, &block)
      end
    end
  end
end
