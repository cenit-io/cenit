module Setup
  class FlowConfig
    include CenitScoped

    FIELDS = %w(active notify_request notify_response discard_events)

    deny :all
    allow :index, :show, :edit

    build_in_data_type

    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    field :active, type: Boolean, default: :true
    field :notify_request, type: Boolean, default: :false
    field :notify_response, type: Boolean, default: :false
    field :discard_events, type: Boolean

    attr_readonly :flow

    validates_presence_of :flow

    before_save do
      self.discard_events = nil if flow.translator.type == :Export && flow.response_translator.blank?
      errors.blank?
    end
  end
end
