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

    def conditions_apply_to?(object_now, object_before = nil, conditions = self.conditions)
      or_cond = conditions['$or']
      and_result = conditions.present? && (or_cond.nil? || conditions.size > 1)
      conditions.each do |field, cond|
        next if field == '$or'
        and_result &&= (values = [object_before && object_before[field], object_now && object_now[field]]) && apply?(cond, *values)
        unless and_result
          if or_cond
            break
          else
            return false
          end
        end
      end
      and_result || (or_cond && or_cond.any? { |c| conditions_apply_to?(object_now, object_before, c) })
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
        old_value != cond && cond == new_value
      end
    end

    # Evaluator for <tt>$present</tt> operator.
    #
    # Usage example:
    #
    #   { "created_at": { "$present": true }  }
    #
    def apply_present_operator?(old_value, new_value, constraint)
      if constraint
        new_value.present? && old_value.blank?
      else
        new_value.blank? && old_value.present?
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

    # Evaluator for <tt>$ne</tt> operator.
    #
    # For example:
    #
    #    { "color": { "$ne": "yellow"" } }
    #
    # applies when a "yellow" <tt>color</tt> attribute takes another value.
    #
    def apply_ne_operator?(old_value, new_value, constraint)
      old_value.eql?(constraint) && !new_value.eql?(constraint)
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
      old_value <= constraint && new_value > constraint
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
      old_value < constraint && new_value >= constraint
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
      old_value >= constraint && new_value < constraint
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
      old_value > constraint && new_value <= constraint
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
      constraint.exclude?(old_value) && constraint.include?(new_value)
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
      constraint.include?(old_value) && constraint.exclude?(new_value)
    end
  end
end
