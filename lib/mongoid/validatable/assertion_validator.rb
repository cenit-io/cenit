module Mongoid
  module Validatable
    class AssertionValidator < ActiveModel::Validator

      def validate(record)
        return unless assertion = options[:assertion]
        assertion = assertion.with_indifferent_access
        if condition_if = eval_condition(record, assertion[:if])
          if error = assertion[:then_error]
            report_error(record, error, assertion[:target])
          else
            report_error(record, assertion[:else], assertion[:target]) unless eval_condition(record, assertion[:then])
          end
        end
      end

      private

      def report_error(record, error, attribute)
        record.errors.add(attribute || :base, error)
      end

      def eval_condition(record, condition)
        return unless condition
        condition_value = true
        condition.each { |attribute, assert| condition_value &&= eval_assert(record, attribute, assert) if condition_value }
        condition_value
      end

      def eval_assert(record, attribute, assert)
        value = record.send(attribute)
        assert_result = true
        assert.each do |assert_key, assert_value|
          next unless assert_result
          assert_result &&=
            case assert_key
            when 'present'
              assert_value ? !value.blank? : value.blank?
            when 'enum'
              assert_value.include?(value)
            when 'format'
              Regexp.new("\\A#{assert_value}\\Z", true) =~ value
            else
              raise Exception.new("Invalid assert key: #{assert_key}")
            end
        end
        assert_result
      end

    end
  end
end