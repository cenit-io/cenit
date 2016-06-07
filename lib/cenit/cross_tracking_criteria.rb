module Cenit
  class CrossTrackingCriteria

    attr_reader :criteria

    def initialize(criteria)
      @criteria = criteria
    end

    def cross(origin = :default)
      new_track_ids = []
      criteria.each do |record|
        next if record.origin == origin
        record.history_tracks.delete_all
        new_track_ids << record.id
      end
      new_criteria = criteria.any_in(id: new_track_ids)
      new_criteria.cross(origin)
      new_criteria.each do |record|
        record.history_tracks.delete_all
        record.version = nil
        record.track_history_for_action("cross #{origin}".to_sym)
      end
      new_criteria.update_all(version: 1)
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