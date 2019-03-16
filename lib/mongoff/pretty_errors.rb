module Mongoff
  module PrettyErrors
    def pretty_errors(record)
      return {} unless record
      errors = record.errors.messages.dup.with_indifferent_access
      if errors.key?(:base) && !property?(:base)
        errors[:'$'] = errors.delete(:base)
      end
      properties.each do |name|
        next unless (model = property_model(name)) && model.modelable?
        errors[name] =
          if (base_errors = errors[name])
            { '$': base_errors }
          else
            {}
          end
        if (associations[name.to_s] || associations[name.to_sym]).many?
          association_errors = record.send(name).map do |associated|
            model.pretty_errors(associated)
          end
          if association_errors.any?(&:present?)
            errors[name]['errors'] = association_errors
          end
        else
          association_errors = model.pretty_errors(record.send(name))
          if association_errors.present?
            errors[name]['errors'] = association_errors
          end
        end
        errors.delete(name) if errors[name].blank?
      end
      errors
    end
  end
end