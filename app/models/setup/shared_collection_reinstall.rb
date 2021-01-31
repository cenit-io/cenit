module Setup
  class SharedCollectionReinstall < Setup::Task

    build_in_data_type

    def run(message)
      collection = Setup::CrossSharedCollection.find(message['shared_collection_id'])
      unless collection.reinstall
        notify(
          type: :error,
          message: "Shared collection #{collection.name} couldn't be reinstalled: #{collection.errors.full_messages.to_sentence}"
        )
      end
    end
  end
end
