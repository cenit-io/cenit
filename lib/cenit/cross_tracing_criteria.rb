module Cenit
  class CrossTracingCriteria

    attr_reader :criteria

    def initialize(criteria)
      @criteria = criteria
    end

    def cross(origin = :default)
      cross_traces = {}
      criteria.each do |record|
        next if record.origin == origin || record.class.origins.exclude?(origin)
        cross_traces[record.id] = record.traces
      end
      cross_criteria = criteria.any_in(id: cross_traces.keys)
      cross_criteria.cross(origin)
      tracked_ids = []
      non_tracked_ids = []
      cross_criteria.each do |record|
        if record.tracing?
          cross_traces[record.id].cross(origin)
          record.trace_action(:cross, "Cross to #{origin}")
          tracked_ids
        else
          non_tracked_ids
        end << record.id
      end
      cross_criteria.any_in(id: non_tracked_ids).update_all(version: nil)
      yield(tracked_ids, non_tracked_ids) if block_given?
    end
  end
end

module CrossOrigin
  class Criteria

    def with_tracing
      Cenit::CrossTracingCriteria.new(self)
    end
  end
end