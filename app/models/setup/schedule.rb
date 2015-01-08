require 'rufus-scheduler'

module Setup
  class Schedule
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    belongs_to :flow, class_name: Setup::Flow.name, inverse_of: :schedule
    field :value, type: Integer
    field :period, type: String
    field :active, type: Boolean, default: :false
    
    after_create :start_scheduler
    
    validates_inclusion_of :value, :in => 1..60,
      :message => "should be between 0 to 60 minutes.", :on => :create
    validates_presence_of :value, :period
    
    def period_enum
      ['seconds', 'minutes', 'hours']
    end
    
    def frequency
      "each #{value} #{period}"
    end  

    private
    
    def start_scheduler
      scheduler = Rufus::Scheduler.new
      scheduler.every(period_symbol) { push_batches }
    end
    
    def push_batches(ts_offset = 5)
      return unless active
      object_count = 0

      last_time = flow.last_trigger_timestamps || Time.at(0)
      this_time = Time.now

      # go 'ts_offset' seconds back in time to catch missing objects
      last_time = last_time - ts_offset.seconds

      model = flow.data_type.model
      scope = model.where(:updated_at.gte => last_time, :updated_at.lte => this_time)

      #Applay filter conditions related with the event associate with flow
      scope = scope.select { |obj| flow.event.triggers_apply_to?(obj) } 
      
      return scope.each { |obj| flow.process(obj) } unless flow.batch.present? 
      
      per_batch = try(flow.batch.size) || 1000
      0.step(scope.count, per_batch) do |offset|
        scope.limit(per_batch).skip(offset).each { |batch| flow.process_batch(batch) } 
      end      
    end
    
    def period_symbol
      case period
      when 'seconds' then "#{value.to_s} s"
      when 'minutes' then "#{value.to_s} m"
      when 'hours'   then "#{value.to_s} h"
      when 'days'    then "#{value.to_s} d"
      end     
    end
    
  end
end
