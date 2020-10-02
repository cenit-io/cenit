module TimeZoneAware
  extend ActiveSupport::Concern

  included do
    field :time_zone, type: String, default: -> { default_time_zone }
  end

  TIME_ZONE_REGEX = /((\+|-)((1[0-3])|(0\d)):\d\d)/

  def default_time_zone
    "#{Time.zone.name} | #{Time.zone.formatted_offset}"
  end

  def validates_time_zone(presence = false)
    if time_zone.blank?
      if presence
        errors.add(:time_zone, "can't be blank")
      else
        remove_attribute(:time_zone)
      end
    else
      errors.add(:time_zone, 'is not valid') unless TIME_ZONE_REGEX.match(time_zone)
    end
  end

  def validates_time_zone!
    validates_time_zone(true)
    abort_if_has_errors
  end

  def time_zone_offset
    time_zone && TIME_ZONE_REGEX.match(time_zone).to_s
  end

  module ClassMethods
    def time_zone_enum
      ActiveSupport::TimeZone.all.collect { |e| "#{e.name} | #{e.formatted_offset}" }
    end
  end
end
