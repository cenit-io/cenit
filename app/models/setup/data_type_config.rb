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
    field :trace_on_default, type: Boolean

    attr_readonly :data_type

    validates_uniqueness_of :data_type
    validates_presence_of :data_type

    after_initialize do
      self.navigation_link = true if data_type.is_a?(Setup::CenitDataType)
    end

    before_save :check_options

    def check_options
      remove_attribute(:navigation_link) if data_type.is_a?(Setup::CenitDataType)
      if has_attribute?(:trace_on_default) && !tracing_option_available?
        remove_attribute(:trace_on_default)
        errors.add(:trace_on_default, 'is not available for the referred data type')
      end
      errors.blank?
    end

    def tracing_option_available?
      data_type &&
        (((model = data_type.records_model).is_a?(Class) &&
          (!model.include(Setup::ClassHierarchyAware) || model.concrete?) &&
          Mongoid::Tracer::Trace::TRACEABLE_MODELS.include?(model)) ||
          (model.is_a?(Mongoff::Model) && !model.is_a?(Mongoff::GridFs::FileModel)))
    end

    def taken?
      slug_taken?(slug)
    end

    class << self
      def config_fields
        %w(slug navigation_link trace_on_default)
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
