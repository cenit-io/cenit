module Setup
  class Push < Setup::Task
    include HashField
    include RailsAdmin::Models::Setup::PushAdmin

    agent_field :source_collection

    build_in_data_type

    belongs_to :source_collection, class_name: Setup::Collection.to_s, inverse_of: nil
    belongs_to :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: nil

    before_save do
      self.source_collection = Setup::Collection.where(id: message[:source_collection_id]).first if source_collection.blank?
      self.shared_collection = Setup::CrossSharedCollection.where(id: message[:shared_collection_id]).first if shared_collection.blank?

      errors.add(:source_collection, "can't be blank") unless source_collection

      if shared_collection
        unless ::User.current_super_admin?
          errors.add(:shared_collection, "origin is not valid (#{shared_collection.origin})") unless shared_collection.origin == :owner
        end
      else
        errors.add(:shared_collection, "can't be blank")
      end

      errors.blank?
    end

    def run(message)
      if (source_collection = Setup::Collection.where(id: (source_collection_id = message[:source_collection_id])).first)
        if (shared_collection = Setup::CrossSharedCollection.where(id: (shared_collection_id = message[:shared_collection_id])).first)
          begin
            if shared_collection.installed?
              unless shared_collection.reinstall(collection: source_collection)
                fail shared_collection.errors.full_messages.to_sentence
              end
            else
              [:title, :readme, :metadata].each do |attr|
                shared_collection.send("#{attr}=", source_collection.send(attr))
              end
              shared_collection.data = source_collection.collecting_data
              fail shared_collection.errors.full_messages.to_sentence unless shared_collection.save
            end
          rescue ::Exception => ex
            fail "Error pushing on shared collection #{shared_collection.versioned_name} (#{ex.message})"
          end
        else
          fail "Shared Collection with id #{shared_collection_id} not found"
        end
      else
        fail "Collection with id #{source_collection_id} not found"
      end
    end
    
  end
end
