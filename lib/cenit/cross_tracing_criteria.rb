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
      traced_ids = []
      no_traced_ids = []
      cross_criteria.each do |record|
        cross_traces[record.id].cross(origin)
        if record.tracing?
          record.trace_action!(:cross, "Cross to #{origin}")
          traced_ids
        else
          no_traced_ids
        end << record.id
      end
      cross_criteria.any_in(id: no_traced_ids).update_all(version: nil)
      yield(traced_ids, no_traced_ids) if block_given?
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