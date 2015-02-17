module EventLookup
  extend ActiveSupport::Concern

  included do

    attr_accessor :discard_event_lookup

    before_save do |object|
      @_obj_before = object.class.where(id: object.id).first
    end

    after_save do |object|
      if discard_event_lookup
        puts "EVENTS DISCARDED"
      else
        Setup::Observer.lookup(self, @_obj_before)
      end
    end
  end

end
