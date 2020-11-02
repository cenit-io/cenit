require 'mongoid/tracer/trace'

module Mongoid
  module Tracer
    class Trace
      include Setup::CenitScoped
      include CrossOrigin::CenitDocument

      Setup::Models.regist(self)

      build_in_data_type.including(:created_at).and(
        properties: {
          target: {}
        }
      )

      allow :read, :destroy

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
    end
  end
end
