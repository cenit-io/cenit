module Setup
  class DataTypeConfig
    include CenitScoped
    include Slug
    include RailsAdmin::Models::Setup::DataTypeConfigAdmin

    deny :all
    allow :index, :show, :new, :edit, :delete, :delete_all, :records

    build_in_data_type

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil, autosave: false

    field :navigation_link, type: Boolean
    field :chart_rendering, type: Boolean
    field :trace_on_default, type: Boolean

    attr_readonly :data_type

    validates_uniqueness_of :data_type
    validates_presence_of :data_type

    before_save :check_options

    def check_options
      unless tracing_option_available?
        remove_attribute(:trace_on_default)
        errors.add(:trace_on_default, 'is not available for the referred data type')
      end
      errors.blank?
    end

    def tracing_option_available?
      data_type && Mongoid::Tracer::Trace::TRACEABLE_MODELS.include?(data_type.records_model)
    end

    def taken?
      slug_taken?(slug)
    end

    class << self
      def config_fields
        %w(slug navigation_link chart_rendering trace_on_default)
      end
    end

    protected

    def slug_candidate
      data_type && data_type.name
    end

    def slug_taken?(slug)
      data_type && self.class.where(slug: slug).any? { |data_type_config| (dt = data_type_config.data_type) && !dt.eql?(data_type) && dt.namespace == data_type.namespace }
    end

  end
end
