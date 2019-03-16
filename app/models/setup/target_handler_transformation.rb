module Setup
  module TargetHandlerTransformation
    def after_execute(options)
      super
      return unless (target = options[:target])
      if !options.key?(:save_result) || options[:save_result]
        target.instance_variable_set(:@discard_event_lookup, options[:discard_events])
        unless Cenit::Utility.save(target)
          fail PersistenceException.new(target)
        end
      end
      options[:result] = target
    end

    class PersistenceException < Exception

      attr_reader :record

      def initialize(record)
        msg =
          if record.new_record?
            "Creating record of data type #{record.orm_model.data_type.custom_title}: "
          else
            "Updating record ##{record.id} of data type #{record.orm_model.data_type.custom_title}: "
          end + record.errors.full_messages.to_sentence
        @record = record
        super(msg)
      end

    end
  end
end
