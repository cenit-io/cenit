module Setup
  class NamespaceCollection < Setup::Task
    include RailsAdmin::Models::Setup::NamespaceCollectionAdmin

    agent_field :target_collection

    build_in_data_type

    belongs_to :target_collection, class_name: Setup::Collection.to_s, inverse_of: nil

    before_save do
      self.target_collection = Setup::Collection.where(id: message['collection_id']).first
    end

    def run(message)
      collection_id = message[:collection_id]
      if (collection = Setup::Collection.where(id: collection_id).first)
        Setup::Collection::COLLECTING_PROPERTIES.each do |property|
          association = Setup::Collection.reflect_on_association(property)
          if association.klass.fields.key?('namespace')
            association_target = collection.send(property)
            association.klass.where(namespace: message[:namespace]).each do |record|
              unless association_target.include?(record)
                association_target << record
              end
            end
          end
        end
        collection.save
      else
        fail "collection with ID #{collection_id} not found"
      end
    end

  end
end
