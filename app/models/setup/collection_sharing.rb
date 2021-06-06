module Setup
  class CollectionSharing < Setup::Task

    include DataUploader

    build_in_data_type

    def run(message)
      collection = Setup::Collection.find(message['collection_id'])
      shared_collection = Setup::CrossSharedCollection.new_from(data.read)
      ok = shared_collection.install(collection: collection)
      fail shared_collection.errors.full_messages.to_sentence if shared_collection.errors.present?
      fail 'Shared process could bit be completed, check your logs' unless ok
      nil
    end
  end
end
