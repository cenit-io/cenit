module Setup
  class FlowConfig
    include CenitScoped
    include RailsAdmin::Models::Setup::FlowConfigAdmin

    deny :all
    allow :index, :show, :edit

    build_in_data_type

    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    field :active, type: Boolean, default: :true
    field :notify_request, type: Boolean, default: :false
    field :notify_response, type: Boolean, default: :false
    field :discard_events, type: Boolean
    field :auto_retry, type: Symbol, default: -> { auto_retry_enum.first }

    attr_readonly :flow

    validates_presence_of :flow

    before_save do
      self.discard_events = nil if (t = flow.translator).nil? || (t.type == :Export && flow.response_translator.blank?)
      errors.blank?
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
