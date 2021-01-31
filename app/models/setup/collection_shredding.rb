module Setup
  class CollectionShredding < Setup::Task

    build_in_data_type

    def run(message)
      collection = Setup::Collection.find(message['collection_id'])
      if collection.destroy
        not_destroyed = []
        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
          collection.send(relation.name).each do |record|
            unless record.destroy
              not_destroyed += record.errors.full_messages
            end
          end
        end
        if not_destroyed.present?
          notify(type: :warning, message: 'Some objects where not destroyed:')
        end
      else
        notify(
          type: :error,
          message: "Collection #{collection.name} couldn't be destroyed: #{collection.errors.full_messages.to_sentence}"
        )
      end
    end
  end
end
