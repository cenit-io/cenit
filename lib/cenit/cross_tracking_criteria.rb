module Cenit
  class CrossTrackingCriteria

    attr_reader :criteria

    def initialize(criteria)
      @criteria = criteria
    end

    def cross(origin = :default)
      new_track_ids = []
      criteria.each do |record|
        next if record.origin == origin || record.class.origins.exclude?(origin)
        record.history_tracks.delete_all
        new_track_ids << record.id
      end
      new_criteria = criteria.any_in(id: new_track_ids)
      new_criteria.cross(origin)
      tracked_ids = []
      non_tracked_ids = []
      new_criteria.each do |record|
        record.history_tracks.delete_all
        record.version = nil
        if record.track_history?
          record.track_history_for_action("cross #{origin}".to_sym)
          tracked_ids
        else
          non_tracked_ids
        end << record.id
      end
      new_criteria.any_in(id: tracked_ids).update_all(version: 1)
      new_criteria.any_in(id: non_tracked_ids).update_all(version: nil)
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