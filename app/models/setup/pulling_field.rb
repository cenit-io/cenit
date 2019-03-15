module Setup
  module PullingField
    extend ActiveSupport::Concern

    module ClassMethods

      def pulling(field, options)
        if @pulling_field
          fail "Pulling field already configured: #{@pulling_field}"
        else
          field = field.to_s.to_sym
          fail 'Option class_name not supplied' unless (klass = options[:class])
          belongs_to field, class_name: klass.to_s, inverse_of: nil
          klass = klass.constantize if klass.is_a?(String)
          klass.class_eval "def pull(message = {}, &block)
            message[:#{field}] = self
            #{to_s}.process(message, &block)
          end"
          @pulling_field = field
        end
        @pulling_field
      end

      def process(message = {}, &block)
        if @pulling_field && (pulling_class = reflect_on_association(@pulling_field).klass)
          case message
          when pulling_class
            pulling = message
            message = {}
          when Hash
            pulling = message.delete(@pulling_field)
          else
            fail 'Invalid message'
          end
          message[:task] = create!(@pulling_field => pulling, message: message)
        end
        super
      end

    end

  end
end
