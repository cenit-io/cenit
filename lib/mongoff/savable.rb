module Mongoff
  module Savable

    def save(options = {})
      errors.clear
      if destroyed?
        errors.add(:base, 'Destroyed record can not be saved')
        return false
      end
      validate(options)
      if orm_model.persistable? && errors.blank?
        begin
          instance_variable_set(:@discard_event_lookup, true) if options[:discard_events]
          run_callbacks_and do
            insert_or_update(options)
          end
          true
        end
      end
      errors.blank?
    end

    def insert_or_update(options = {})
      if new_record?
        r = orm_model.collection.insert_one(attributes)
        unless id == r.inserted_ids[0]
          self.id = r.inserted_ids[0]
        end
        set_not_new_record
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
      true
    end
  end
end