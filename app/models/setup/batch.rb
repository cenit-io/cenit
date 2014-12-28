module Setup
  class Batch
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    belongs_to :flow, class_name: Setup::Flow.name, inverse_of: :batch
    field :size, type: Integer
    
    validates_numericality_of :size, :greater_than => 0,
      :message => "should be greater than 0", :on => :create
      
    validates_presence_of :size   
  end
end
