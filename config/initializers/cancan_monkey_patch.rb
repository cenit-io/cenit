module CanCan
  module ModelAdapters
    class MongoidAdapter

      def database_records
        if @rules.size == 0
          @model_class.where(_id: {'$exists' => false, '$type' => 7})
        elsif @rules.size == 1 && @rules[0].conditions.is_a?(Mongoid::Criteria)
          @rules[0].conditions
        else
          rules = @rules.reject { |rule| rule.conditions.empty? && rule.base_behavior }
          process_can_rules = @rules.count == rules.count

          rules_scope =
            rules.inject(@model_class.unscoped) do |records, rule|
              if process_can_rules && rule.base_behavior
                records.or rule.conditions
              elsif !rule.base_behavior
                records.excludes rule.conditions
              else
                records
              end
            end
          @model_class.all.and(rules_scope.selector)
        end
      end
    end
  end
end