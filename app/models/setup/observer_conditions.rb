require 'set'

module Setup
  module ObserverConditions
    extend ActiveSupport::Concern

    include HashField

    included do

      build_in_data_type.and(
          properties: {
              conditions: {
                  type: 'object'
              }
          }
      )

      hash_field :conditions
    end

    def validate_field_condition(conditions)
      conditions.each do |field, cond|
        if (match = field.match(/\A\$(.+)/))
          if self.respond_to?("apply_#{match[1]}_operator?")
            if field == '$regex'
              begin
                Regexp.new(cond)
              rescue
                errors.add(:conditions, "have the following error conforming regular expression: #{ex.message}")
              end
            else
              case cond
              when Array
                unless field == '$in' || field == '$nin' || field == '$elemMatch' || field == '$all'
                  errors.add(:conditions, "cannot apply the operator #{field} to a array #{cond}.")
                end
                unless field == '$elemMatch' && cond.size > 0 && cond.all? { |c| validate_conditions?(c) }
                  errors.add(:conditions, "have invalid array of conditions #{cond} for operator #{field}.")
                end
              when Hash
                unless field == '$elemMatch' && validate_conditions?(cond)
                  errors.add(:conditions, "have invalid condition #{cond} for operator #{field}.")
                end
              else
                # ?
              end
            end
          else
            errors.add(:conditions, "have an invalid operator #{field} in a field.")
          end
        else
          errors.add(:conditions, '?')
        end
        break unless errors.blank?
      end
      errors.blank?
    end

    def validate_conditions?(conditions = self.conditions)
      if conditions.present?
        conditions.each do |field, cond|
          if field == '$or' || field == '$and' || field == '$nor'
            if cond.is_a?(Array) && cond.size > 1
              return false unless cond.all? { |c| validate_conditions?(c) }
            else
              errors.add(:conditions, "have no arguments for #{field} clause.")
              return false
            end
          elsif field == '$not'
            if cond.is_a?(Array)
              if cond.size > 0
                return false unless cond.all? { |c| validate_conditions?(c) }
              else
                errors.add(:conditions, "have no arguments for #{field} clause.")
                return false
              end
            else
              return false unless validate_conditions?(cond)
            end
          else
            if field.match(/\A\$(.+)/)
              errors.add(:conditions, "contains #{field} operator non associated to fields.")
              return false
            end
            if cond.is_a?(Hash)
              return false unless validate_field_condition?(cond)
            end
          end
        end
      else
        errors.add(:conditions, "is invalid one.")
        return false
      end
      return true
    end

    def conditions_apply_to?(object_now, object_before = nil, conditions = self.conditions)
      if conditions.present?
        conditions.each do |field, cond|
          partial_eval = false
          if field == '$or'
            partial_eval = cond.any? { |c| conditions_apply_to?(object_now, object_before, c) }
          elsif field == '$and'
            partial_eval = cond.all? { |c| conditions_apply_to?(object_now, object_before, c) }
          elsif field == '$not'
            partial_eval = !conditions_apply_to?(object_now, object_before, cond)
          elsif field == '$nor'
            partial_eval = cond.all? { |c| !conditions_apply_to?(object_now, object_before, c) }
          else
            values = [object_before && object_before[field], object_now && object_now[field]]
            partial_eval = values && apply?(cond, *values)
          end
          return false unless partial_eval
        end
      end
      true
    end

    # Determines if a condition applies to a given pair of old-new values. If the condition
    # is a Hash then each entry must define an operator and a respective constraint.
    #
    # For example:
    #
    #   { "checked": true }
    #
    # applies when the <tt>checked</tt> attribute becomes true, while
    #
    #    { "price": { "$get": 100 } }
    #
    # applies when the <tt>price</tt> becomes greater or equals than 100.
    #
    def apply?(cond, old_value, new_value)
      if cond.is_a?(Hash)
        cond.each do |op, constraint|
          if (match = op.match(/\A\$(.+)/))
            begin
              return false unless send("apply_#{match[1]}_operator?", old_value, new_value, constraint)
            rescue Exception => ex
              fail "Error executing operator #{op}: #{ex.message}"
            end
          else
            fail "Invalid operator #{op}"
          end
        end
        true
      else
        old_value != cond && cond == new_value # the $eq operator
      end
    end

    # Evaluator for <tt>$changes</tt> operator. If the operator constraint
    # truthy value is not true then the operator does not applies.
    #
    # Usage example:
    #
    #   { "updated_at": { "$changes": true }  }
    #
    def apply_changes_operator?(old_value, new_value, constraint)
      constraint && (new_value != old_value)
    end

    # Evaluator for <tt>$size</tt> operator.
    #
    # For example:
    #
    #    { "field_array": { "$size": 3 } }
    #
    #
    def apply_size_operator?(old_value, new_value, constraint)
      (!old_value || old_value.size != constraint) && new_value.size == constraint
    end

    # Evaluator for <tt>regex</tt> operator.
    #
    # For example:
    #
    #    { "field": { "$regex": "^m" }
    #
    #
    def apply_regex_operator?(old_value, new_value, constraint)
      regex_pattern = Regexp.new(constraint)
      (!old_value || !(old_value =~ regex_pattern)) && new_value =~ regex_pattern
    end

    # Evaluator for <tt>$elemMatch</tt> operator.
    #
    # For example:
    #
    #    { "field_array": { "$elemMatch": {b:1, c: 2} } }
    #
    #
    def apply_elemMatch_operator?(old_value, new_value, constraint)
      (!old_value || !(old_value.any? { |c| conditions_apply_to?(c, nil, constraint) })) &&
        new_value.any? { |c| conditions_apply_to?(c, nil, constraint) }
    end

    # Evaluator for <tt>$all</tt> operator.
    #
    # For example:
    #
    #    { "field_array": { "$all": [10, 25, 30, "hello"] } }
    #
    #
    def apply_all_operator?(old_value, new_value, constraint)
      (!old_value || !(old_value.to_set.superset?(constraint.to_set))) &&
        new_value.to_set.superset?(constraint.to_set)
    end

    # Evaluator for <tt>$mod</tt> operator.
    #
    # For example:
    #
    #    { "age": { "$mod": [2, 1] } }
    #
    # applies when a "age" attribute is odd.
    #
    def apply_mod_operator?(old_value, new_value, constraint)
      (!old_value || old_value % constraint[0] == constraint[1]) && new_value % constraint[0] == constraint[1]
    end

    # Evaluator for <tt>$eq</tt> operator.
    #
    # For example:
    #
    #    { "color": { "$eq": "yellow"" } }
    #
    # applies when a "yellow" <tt>color</tt> attribute takes this value.
    #
    def apply_eq_operator?(old_value, new_value, constraint)
      (!old_value || !old_value.eql?(constraint)) && new_value.eql?(constraint)
    end

    # Evaluator for <tt>$ne</tt> operator.
    #
    # For example:
    #
    #    { "color": { "$ne": "yellow"" } }
    #
    # applies when a "yellow" <tt>color</tt> attribute takes another value.
    #
    def apply_ne_operator?(old_value, new_value, constraint)
      (!old_value || old_value.eql?(constraint)) && !new_value.eql?(constraint)
    end


    # Evaluator for <tt>$gt</tt> operator.
    #
    # For example:
    #
    #    { "price": { "$gt": 100 } }
    #
    # applies when the <tt>price</tt> becomes greater than 100.
    #
    def apply_gt_operator?(old_value, new_value, constraint)
      (!old_value || old_value <= constraint) && (new_value > constraint)
    end

    # Evaluator for <tt>$gte</tt> operator.
    #
    # For example:
    #
    #    { "price": { "$gte": 100 } }
    #
    # applies when the <tt>price</tt> becomes greater than or equals to 100.
    #
    def apply_gte_operator?(old_value, new_value, constraint)
      (!old_value || old_value < constraint) && new_value >= constraint
    end

    # Evaluator for <tt>$lt</tt> operator.
    #
    # For example:
    #
    #    { "price": { "$lt": 100 } }
    #
    # applies when the <tt>price</tt> becomes less than 100.
    #
    def apply_lt_operator?(old_value, new_value, constraint)
      (!old_value || old_value >= constraint) && new_value < constraint
    end

    # Evaluator for <tt>$lte</tt> operator.
    #
    # For example:
    #
    #    { "price": { "$lte": 100 } }
    #
    # applies when the <tt>price</tt> becomes less than or equals to 100.
    #
    def apply_lte_operator?(old_value, new_value, constraint)
      (!old_value || old_value > constraint) && new_value <= constraint
    end

    # Evaluator for <tt>$in</tt> operator.
    #
    # For example:
    #
    #    { "color": { "$in": ["red", "green", "blue"] } }
    #
    # applies when a non RGB <tt>color</tt> takes one of the RGB values.
    #
    def apply_in_operator?(old_value, new_value, constraint)
      (!old_value || constraint.exclude?(old_value)) && constraint.include?(new_value)
    end

    # Evaluator for <tt>$nin</tt> operator.
    #
    # For example:
    #
    #    { "color": { "$nin": ["red", "green", "blue"] } }
    #
    # applies when an RGB <tt>color</tt> becomes a non RGB value.
    #
    def apply_nin_operator?(old_value, new_value, constraint)
      (!old_value || constraint.include?(old_value)) && constraint.exclude?(new_value)
    end
  end
end
