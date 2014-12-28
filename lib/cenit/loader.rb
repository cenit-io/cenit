require 'json'

module Cenit
  class Loader

      attr_accessor :payload, :parameters, :request_id

      def initialize(message)
        self.payload = ::JSON.parse(message).with_indifferent_access
        self.request_id = payload.delete(:request_id)
        if payload.key? :parameters
          if payload[:parameters].is_a? Hash
            self.parameters = payload.delete(:parameters).with_indifferent_access
          end
        end
        self.parameters ||= {}
      end

      def response(message, code = 200)
        Cenit::Responder.new(@request_id, message, code)
      end

      def process
        connection = Setup::Connection.where(name: self.payload[:connection]).first
        return response "Missing Connection!", 500 unless connection
        
        connection_role = Setup::ConnectionRole.find_or_create_by(name: connection.name)
        connection.connection_roles << connection_role unless connection.connection_roles.include?(connection_role)

        library = Setup::Library.find_or_create_by(name: self.payload[:library])

        data_type = nil
        root = self.payload[:root]
        schema = Setup::Schema.where(uri: root).first
        if schema.nil?
          return response "Missing Schema", 500 if self.payload[:schema].nil?
          schema_attributes = {
            library: library,
            uri: root,
            schema: self.payload[:schema],
          }
          schema = Setup::Schema.create(schema_attributes)
          data_type = schema.data_types.first
          data_type.load_model
          data_type.create_default_events
        else
          data_type = schema.data_types.first
        end

        set_webhook_flow(root, 'created_at', 'add', connection_role, data_type)
        set_webhook_flow(root, 'updated_at', 'update', connection_role, data_type)

        response "Configuration added!"
      end

      def set_webhook_flow(root, event, method, connection_role, data_type)
        webhook_name = "#{method.capitalize} #{root} #{connection_role.name}"
        webhook = Setup::Webhook.where(name: webhook_name).first
        unless webhook
          webhook_attributes = {
            name: webhook_name,
            purpose: 'send',
            connection_id: connection.id,
            path: "#{method}_#{root.downcase}"
          }
          webhook = Setup::Webhook.create(webhook_attributes)
        end
        
        webhook.connection_roles << connection_role unless webhook.connection_roles.include?(connection_role)

        event = Setup::Event.find_by(name: "#{root} on #{event}")
        flow_name = "#{method.capitalize} #{root} to #{connection_role.name}"
        flow = Setup::Flow.where(name: flow_name).first
        unless flow
          flow_attributes = {
            name: flow_name,
            active: true,
            purpose: 'send',
            data_type_id: data_type.id,
            connection_role_id: connection_role.id,
            webhook_id: webhook.id,
            event_id: event.id
          }
          Setup::Flow.create(flow_attributes)
        end
      end

  end
end
