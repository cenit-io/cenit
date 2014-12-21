module Setup
  class Schedule
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped

    belongs_to :flow, class_name: Setup::Flow.name, inverse_of: :schedule
    field :value, type: Integer
    field :period, type: String
    
    validates_inclusion_of :value, :in => 1..60,
      :message => "should be between 0 to 60 minutes.", :on => :create
    validates_presence_of :value, :period
    
    def period_enum
      ['seconds', 'minutes', 'hours']
    end
    
  end
end
