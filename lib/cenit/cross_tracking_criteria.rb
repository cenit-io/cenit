module Cenit
  class CrossTrackingCriteria

    attr_reader :criteria

    def initialize(criteria)
      @criteria = criteria
    end

    def cross(origin = :default)
      cross_tracks = {}
      criteria.each do |record|
        next if record.origin == origin || record.class.origins.exclude?(origin)
        cross_tracks[record.id] = record.history_tracks
      end
      cross_criteria = criteria.any_in(id: cross_tracks.keys)
      cross_criteria.cross(origin)
      tracked_ids = []
      non_tracked_ids = []
      cross_criteria.each do |record|
        if record.track_history?
          cross_tracks[record.id].cross(origin)
          record.track_history_for_action!("cross #{origin}".to_sym)
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

    def with_tracking
      Cenit::CrossTrackingCriteria.new(self)
    end
  end
end