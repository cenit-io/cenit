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
        connection_roles_attributes: permitted_connection_role_attributes,
        parameters_attributes: permitted_parameter_attributes,
        headers_attributes: permitted_parameter_attributes,
        templates_parameter: permitted_parameter_attributes,
      ]
    end
    
    def permitted_connection_role_attributes
      permitted_attributes.connection_role_attributes + [
        webhooks_attributes: permitted_webhook_attributes
      ]
    end
    
    def permitted_webhook_attributes
      permitted_attributes.webhook_attributes + [
        parameters_attributes: permitted_parameter_attributes,
        headers_attributes: permitted_parameter_attributes,
        templates_parameter: permitted_parameter_attributes,
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
        schemas_attributes: permitted_schema_attributes,
        validators_attributes: permitted_validator_attributes,
      ]
    end

    def permitted_collection_attributes
      permitted_attributes.collection_attributes + [
        connection_roles_attributes: permitted_connection_role_attributes,
        flows_attributes: permitted_flow_attributes,
        libraries_attributes: permitted_library_attributes,
        events_attributes: permitted_event_attributes,
        translators_attributes: permitted_translator_attributes,
        webhooks_attributes: permitted_webhook_attributes,
        connections_attributes: permitted_connection_attributes,
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