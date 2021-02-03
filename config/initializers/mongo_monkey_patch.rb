require 'mongo/operation/insert/op_msg'

module Mongo
  module Operation

    KEYS_VALIDATION_KEY = :'[mongo][operation]:validating_keys'

    class Insert

      class OpMsg
        def message(connection)
          validating_keys = true
          if Thread.current.key?(Mongo::Operation::KEYS_VALIDATION_KEY)
            validating_keys = Thread.current[Mongo::Operation::KEYS_VALIDATION_KEY]
          end
          section = Protocol::Msg::Section1.new(IDENTIFIER, send(IDENTIFIER))
          Protocol::Msg.new(flags, { validating_keys: validating_keys }, command(connection), section)
        end
      end
    end
  end
end
