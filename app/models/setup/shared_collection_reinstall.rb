module Setup
  class SharedCollectionReinstall < Setup::Task

    agent_field :shared_collection, :shared_collection_id

    build_in_data_type

    belongs_to :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: nil

    def run(message)
      if (collection = agent_from_msg)
        unless collection.reinstall
          notify(
            type: :error,
            message: "Shared collection #{collection.name} couldn't be reinstalled: #{collection.errors.full_messages.to_sentence}"
          )
        end
      else
        fail "Shared collection with id #{shared_collection_id} not found"
      end
    end
  end
end
