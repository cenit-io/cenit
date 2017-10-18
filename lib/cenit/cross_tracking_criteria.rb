module Cenit
  class CrossTrackingCriteria

    attr_reader :criteria

    def initialize(criteria)
      @criteria = criteria
    end

    def cross(origin = :default)
      new_tracks = {}
      criteria.each do |record|
        next if record.origin == origin || record.class.origins.exclude?(origin)
        new_tracks[record.id] = record.history_tracks.view
      end
      new_criteria = criteria.any_in(id: new_tracks.keys)
      new_criteria.cross(origin)
      tracked_ids = []
      non_tracked_ids = []
      new_criteria.each do |record|
        record.history_tracks.delete_all
        if record.track_history?
          record.history_tracker_class.collection.insert_many(new_tracks[record.id].to_a)
          new_tracks[record.id].delete_many
          record.track_history_for_action!("cross #{origin}".to_sym)
          tracked_ids
        else
          non_tracked_ids
        end << record.id
      end
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