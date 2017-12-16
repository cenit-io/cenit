require 'mongoid/tracer/trace'

module Mongoid
  module Tracer
    class Trace
      include Setup::CenitScoped
      include CrossOrigin::CenitDocument
      include RailsAdmin::Models::Mongoid::Tracer::TraceAdmin

      build_in_data_type

      deny :all
      allow :index, :show, :member_trace_index, :collection_trace_index

      origins :default, -> { Cenit::MultiTenancy.tenant_model.current && :owner }, :shared

      def target_model
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
          #   Setup::BaseOauthProvider.class_hierarchy +
          #   Setup::Translator.class_hierarchy +
          [
            Setup::Algorithm,
            Setup::Connection,
            Setup::JsonDataType
          # Setup::PlainWebhook,
          # Setup::Resource,
          # Setup::Flow,
          # Setup::Oauth2Scope,
          # Setup::Snippet,
          # Setup::RemoteOauthClient
          ] -
          [
            Setup::CenitDataType
          ]
    end
  end
end
