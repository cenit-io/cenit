require 'mongoid/tracer/trace'

module Mongoid
  module Tracer
    class Trace
      include Setup::CenitScoped
      include CrossOrigin::CenitDocument

      build_in_data_type.and(
        label: '{{action}} at {{created_at | date: "%Y-%m-%d %H:%M"}}',
        with_origin: true,
        properties: {
          target: {
            type: 'object'
          },
          changes_set: {
            type: 'object'
          }
        }
      )

      allow :read, :delete

      origins -> { Cenit::MultiTenancy.tenant_model.current && [:default, :owner] }, :shared

      belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil

      attr_readonly :data_type

      before_create do
        self.data_type = target.orm_model.data_type
        true
      end

      def target_model
        data_type&.records_model ||
          if (match = target_model_name.match(/\ADt(.+)\Z/))
            if (data_type = Setup::DataType.where(id: match[1]).first)
              puts "DT #{match[1]} / #{target_model_name} -> #{data_type}"
              data_type.records_model
            else
              fail "Data type with ID #{match[1]} does not exist"
            end
          else
            target_model_name.constantize
          end
      end

      def label
        "#{action.to_s.capitalize} at #{created_at}"
      end

      TRACEABLE_MODELS =
        #   Setup::Validator.class_hierarchy +
        #   Setup::AuthorizationProvider.class_hierarchy +
        #   Setup::Translator.class_hierarchy +
        [
          Setup::Algorithm,
          Setup::Connection,
          Setup::JsonDataType,
          Setup::Snippet
        # Setup::PlainWebhook,
        # Setup::Resource,
        # Setup::Flow,
        # Setup::Oauth2Scope,
        # Setup::RemoteOauthClient,
        # Setup::AuthorizationClient
        ] -
          [
            Setup::CenitDataType
          ]

      def insert_as_root(&block)
        self.class.skip_keys_validation do
          super(&block)
        end
      end

      class << self

        def skip_keys_validation
          key = ::Mongo::Operation::KEYS_VALIDATION_KEY
          current_keys_validation = Thread.current[key]
          Thread.current[key] = false
          yield if block_given?
        ensure
          Thread.current[key] = current_keys_validation
        end

        def with(*args, &block)
          skip_keys_validation do
             super(*args, &block)
          end
        end
      end
    end
  end
end
