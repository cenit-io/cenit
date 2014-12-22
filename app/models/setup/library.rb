module Setup
  class Library
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    field :name, type: String

    has_many :schemas, class_name: Setup::Schema.to_s, dependent: :destroy

    validates_presence_of :name
    validates_uniqueness_of :name

    def find_data_type_by_name(name)
      self.schemas.each do |schema|
        if data_type = schema.data_types.where(name: name).first
          return data_type
        end
      end
      nil
    end

    rails_admin do

      edit do
        field :name do
          read_only { !bindings[:object].new_record? }
          help ''
        end
      end
    end

  end
end
