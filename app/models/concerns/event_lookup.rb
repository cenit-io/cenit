module EventLookup
  extend ActiveSupport::Concern

  included do
    before_save do |object|
      @_obj_before = object.class.where(id: object.id).first unless new_record?
    end

    after_save Mongoff::Model.after_save
  end
end
