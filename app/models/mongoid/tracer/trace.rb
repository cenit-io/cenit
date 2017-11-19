require 'mongoid/tracer/trace'

module Mongoid
  module Tracer


    class Trace
      include Setup::CenitScoped
      include CrossOrigin::CenitDocument

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
        # Setup::DataType.class_hierarchy +
        #   Setup::Validator.class_hierarchy +
        #   Setup::BaseOauthProvider.class_hierarchy +
        #   Setup::Translator.class_hierarchy +
        [
          Setup::Algorithm
        # Setup::Connection,
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

      rails_admin do

        object_label_method :label

        configure :target_id, :json_value do
          label 'Target ID'
        end

        configure :target_model, :model do
          visible do
            bindings[:controller].action_name == 'index'
          end
        end

        configure :target, :record do
          visible do
            bindings[:controller].action_name != 'member_trace_index'
          end
        end

        configure :action do
          pretty_value do
            if (msg = bindings[:object].message)
              "#{msg} (#{bindings[:object].action})"
            else
              value.to_s.to_title
            end
          end
        end

        configure :attributes_trace, :json_value

        fields :target_model, :target, :action, :attributes_trace, :created_at

        filter_fields :target_id, :action, :attributes_trace, :created_at
      end
    end
  end
end
