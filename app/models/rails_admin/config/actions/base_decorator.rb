module RailsAdmin
  module Config
    module Actions
      Base.class_eval do
        register_instance_option :template_name do
          ((absm = bindings[:abstract_model]) && absm.config.with(action: self).template_name) || key.to_sym
        end

        register_instance_option :bulk_processable? do
          false
        end
      end
    end
  end
end
