Mongoid.default_client.database.collection_names(filter: { name: /setup_algorithms\Z/ }).each do |collection_name|
  collection = Mongoid.default_client[collection_name.to_s.to_sym]
  collection.find.each do |alg|
    collection.update_one(
      { _id: alg['_id'] },
      '$set' => { 'parameters_size' => alg['parameters']&.size || 0 }
    )
  end
end