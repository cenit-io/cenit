module Mongoff
  module PrettyErrors
    def pretty_errors(record, stack = Set.new)
      return {} unless record
      stack << record
      errors = record.errors.messages.dup.with_indifferent_access
      if errors.key?(:base) && !property?(:base)
        errors[:'$'] = errors.delete(:base)
      end
      properties.each do |name|
        next unless (model = property_model(name)) && model.modelable?
        errors[name] =
          if (base_errors = errors[name]).present?
            { '$': base_errors }
          else
            {}
          end
        if (associations[name.to_s] || associations[name.to_sym]).many?
          record.send(name).each_with_index do |associated, index|
            begin
              next if stack.include?(associated)
            rescue
              next
            end
            next unless (associated_errors = model.pretty_errors(associated, stack)).present?
            errors[name][index] = associated_errors
          end
        else
          associated = record.send(name)
          unless stack.include?(associated)
            association_errors = model.pretty_errors(associated, stack)
            if association_errors.present?
              errors[name].merge!(association_errors)
            end
          end
        end
        errors.delete(name) if errors[name].blank?
      end
      stack.delete(record)
      errors
    end
  end
end