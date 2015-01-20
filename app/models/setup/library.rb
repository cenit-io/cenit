module Setup
  class Library
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    field :name, type: String

    has_many :schemas, class_name: Setup::Schema.to_s, inverse_of: :library, dependent: :destroy
    has_many :templates, class_name: Setup::Template.name, inverse_of: :library, dependent: :destroy

    validates_presence_of :name
    validates_uniqueness_of :name

    def find_data_type_by_name(name)
      DataType.where(name: name).detect { |data_type| data_type.uri.library == self }
    end

  end
end
