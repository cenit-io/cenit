module Setup
  class Translator
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    field :name, type: String
    field :purpose, type: Symbol
    field :script, type: String

    validates_presence_of :name

    def purpose_enum
      [:send, :receive, :update]
    end

    def run(options={})
      object = options[:object]
      data_type = options[:data_type]
      data = options[:data]
      eval(script)
    end
  end
end