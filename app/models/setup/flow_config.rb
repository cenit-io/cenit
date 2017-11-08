module Setup
  class FlowConfig
    include CenitScoped
    include RailsAdmin::Models::Setup::FlowConfigAdmin

    deny :all
    allow :index, :show, :new, :edit, :delete, :delete_all

    build_in_data_type

    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil, autosave: false

    field :active, type: Boolean
    field :notify_request, type: Boolean
    field :notify_response, type: Boolean
    field :discard_events, type: Boolean
    field :auto_retry, type: Symbol

    attr_readonly :flow

    validates_presence_of :flow
    validates_uniqueness_of :flow

    before_save do
      self.discard_events = nil if (t = flow.translator).nil? || (t.type == :Export && flow.response_translator.blank?)
      remove_attribute(:auto_retry) if auto_retry.blank?
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
