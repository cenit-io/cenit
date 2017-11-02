module Setup
  class DataTypeConfig
    include CenitScoped
    include Slug
    include RailsAdmin::Models::Setup::DataTypeConfigAdmin

    deny :all
    allow :index, :show, :new, :edit, :delete, :delete_all

    build_in_data_type

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil, autosave: false

    field :navigation_link, type: Boolean
    field :chart_rendering, type: Boolean
    field :trace_by_default, type: Boolean

    attr_readonly :data_type

    validates_uniqueness_of :data_type
    validates_presence_of :data_type

    def taken?
      slug_taken?(slug)
    end

    class << self
      def config_fields
        %w(slug navigation_link chart_rendering trace_by_default)
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
