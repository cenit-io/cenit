module Setup
  class Filter
    include CenitScoped
    include NamespaceNamed
    include TriggersFormatter
    include CustomTitle
    include RailsAdmin::Models::Setup::FilterAdmin

    build_in_data_type.referenced_by(:namespace, :name)

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    field :triggers, type: String

    before_save :format_triggers, :check_name

    def ready_to_save?
      data_type.present?
    end

    def can_be_restarted?
      ready_to_save?
    end

    def to_s
      name ? name : super
    end

    def segment
      JSON.parse triggers.gsub(/:(\w+)/){"\"#{$1}\""}.gsub('=>', ':')
    end

    private

    def format_triggers
      if data_type.blank?
        errors.add(:data_type, "can't be blank")
      elsif triggers.present?
        format_triggers_on(:triggers, true)
      else
        errors.add(:base, 'Triggers missing')
      end
      errors.blank?
    end

    def check_name
      if name.blank?
        hash = JSON.parse(triggers)
        triggered_fields = hash.keys
        n = "#{self.data_type.custom_title} on #{triggered_fields.to_sentence}"
        i = 1
        self.name = n
        while Setup::Query.where(name: name).present? do
          self.name = n + " (#{i+=1})"
        end
      end
    end

  end
end

class String

  def to_boolean
    self == 'true'
  end

end
