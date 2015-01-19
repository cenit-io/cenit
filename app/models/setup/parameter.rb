module Setup
  class Parameter
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    
    belongs_to :parameterizable, polymorphic: true

    field :key, type: String
    field :value, type: String

    validates_presence_of :key, :value
    
    def to_s
      "#{key}: #{value}"
    end  
      
  end 
end
