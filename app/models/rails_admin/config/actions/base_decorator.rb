module RailsAdmin
  module Config
    module Actions
      Base.class_eval do

        #TODO Remove this option when rendering attributes traces field using other field type than :code
        register_instance_option :listing? do
          false
        end

        register_instance_option :template_name do
          ((absm = bindings[:abstract_model]) && absm.config.with(action: self).template_name) || key.to_sym
        end

        register_instance_option :bulk_processable? do
          false
        end

        def url_options(opts = {})
          opts[:action] ||= action_name
          opts[:controller] ||= 'rails_admin/main'
          opts[:model_name] ||= bindings[:abstract_model].try(:to_param)
          opts[:id] ||=  ((object = bindings[:object]) && object.try(:persisted?) && object.try(:id)) || nil
          opts
        end
      end
    end
  end
end
