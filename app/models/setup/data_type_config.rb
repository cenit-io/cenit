module Setup
  class DataTypeConfig
    include CenitScoped
    include Slug

    FIELDS = %w(slug navigation_link)

    deny :all
    allow :index, :show, :edit

    build_in_data_type

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :navigation_link, type: Boolean

    attr_readonly :data_type

    validates_presence_of :data_type

    def taken?
      slug_taken?(slug)
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
