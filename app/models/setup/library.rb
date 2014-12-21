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

    # def module_name
    #   "Lib#{self.id.to_s}"
    # end
    #
    # def module
    #   m = module_name.constantize rescue nil
    #   unless m
    #     Object.const_set(module_name, m = Module.new)
    #   end
    #   return m
    # end

  end
end
