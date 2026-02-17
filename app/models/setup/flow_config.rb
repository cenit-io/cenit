module Setup
  class FlowConfig
    include CenitScoped

    build_in_data_type.and(
      label: '{{flow.namespace}} | {{flow.name}} [config]'
    )

    belongs_to :flow, class_name: 'Setup::Flow', inverse_of: nil, autosave: false

    field :active, type: Mongoid::Boolean
    field :notify_request, type: Mongoid::Boolean
    field :notify_response, type: Mongoid::Boolean
    field :discard_events, type: Mongoid::Boolean
    field :auto_retry, type: StringifiedSymbol

    attr_readonly :flow

    validates_presence_of :flow
    validates_uniqueness_of :flow

    before_save do
      self.discard_events = nil if (t = flow.translator).nil? || (t.type == :Export && flow.response_translator.blank?)
      remove_attribute(:auto_retry) if auto_retry.blank?
      abort_if_has_errors
    end

    def auto_retry_enum
      Setup::Task.auto_retry_enum
    end

    class << self

      def config_fields
        %w(active notify_request notify_response discard_events auto_retry)
      end

    end

  end
end
