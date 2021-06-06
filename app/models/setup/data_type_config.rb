module Setup
  class DataTypeConfig
    include CenitScoped
    include Slug

    build_in_data_type.and(
      label: '{{data_type.namespace}} | {{data_type.name}} [config]'
    )

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil, autosave: false

    field :trace_on_default, type: Boolean

    attr_readonly :data_type

    validates_uniqueness_of :data_type
    validates_presence_of :data_type

    before_save :check_options

    def check_options
      if has_attribute?(:trace_on_default) && !tracing_option_available?
        remove_attribute(:trace_on_default)
        errors.add(:trace_on_default, 'is not available for the referred data type')
      end
      abort_if_has_errors
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
        %w(slug trace_on_default)
      end
    end

    protected

    def slug_candidate
      data_type&.name
    end

    def slug_taken?(slug)
      data_type &&
        self.class.where(slug: slug).any? do |data_type_config|
          (dt = data_type_config.data_type) && !dt.eql?(data_type) && dt.namespace == data_type.namespace
        end
    end

  end
end
