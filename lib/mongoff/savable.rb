module Mongoff
  module Savable

    def save(options = {})
      errors.clear
      if destroyed?
        errors.add(:base, 'Destroyed record can not be saved')
        return false
      end
      validate
      begin
        instance_variable_set(:@discard_event_lookup, true) if options[:discard_events]
        run_callbacks_and do
          if new_record?
            orm_model.collection.insert_one(attributes)
            @new_record = false
          else
            query = orm_model.collection.find(_id: id)
            set = attributes
            unset = {}
            if (doc = query.first)
              doc.keys.each { |key| unset[key] = '' unless set.has_key?(key) }
            end
            update = { '$set' => set }
            if unset.present?
              update['$unset'] = unset
            end
            query.update_one(update)
          end
        end
      end if orm_model.persistable? && errors.blank?
      errors.blank?
    end

  end
end