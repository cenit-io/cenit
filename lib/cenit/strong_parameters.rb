module Cenit
  module StrongParameters
    def permitted_attributes
      Cenit::PermittedAttributes
    end

    delegate *Cenit::PermittedAttributes::ATTRIBUTES,
                     to: :permitted_attributes,
                     prefix: :permitted
                     
    def permitted_connection_attributes
      permitted_attributes.connection_attributes + [
        connection_role_attributes: permitted_connection_role_attributes,
        parameter_attributes: permitted_parameter_attributes,
        header_attributes: permitted_parameter_attributes,
        template_parameter: permitted_parameter_attributes,
      ]
    end
    
    def permitted_connection_role_attributes
      permitted_attributes.connection_role_attributes + [
        webhook_attributes: permitted_webhook_attributes,
        connection_attributes: permitted_connection_attributes,
      ]
    end
    
    def permitted_webhook_attributes
      permitted_attributes.webhook_attributes + [
        connection_role_attributes: permitted_connection_role_attributes,
        parameter_attributes: permitted_parameter_attributes,
        header_attributes: permitted_parameter_attributes,
        template_parameter: permitted_parameter_attributes,
      ]
    end
    
    def permitted_flow_attributes
      permitted_attributes.flow_attributes
    end

    def permitted_validator_attributes
      permitted_attributes.validator_attributes
    end
    
    def permitted_event_attributes
      permitted_attributes.event_attributes
    end
    
    def permitted_library_attributes
      permitted_attributes.library_attributes + [
        schema_attributes: permitted_schema_attributes,
        validator_attributes: permitted_validator_attributes,
      ]
    end

    def permitted_collection_attributes
      permitted_attributes.collection_attributes + [
        connection_role_attributes: permitted_connection_role_attributes,
        flow_attributes: permitted_flow_attributes,
        library_attributes: permitted_library_attributes,
        event_attributes: permitted_event_attributes,
        translator_attributes: permitted_translator_attributes,
        webhook_attributes: permitted_webhook_attributes,
        connection_attributes: permitted_connection_attributes,
      ]
    end

    def permitted_parameter_attributes
      permitted_attributes.parameter_attributes
    end
    
    def permitted_traslator_attributes
      permitted_attributes.traslator_attributes
    end
    
    def permitted_scheduler_attributes
      permitted_attributes.scheduler_attributes
    end
    
    def permitted_observer_attributes
      permitted_attributes.observer_attributes
    end
    
  end
end