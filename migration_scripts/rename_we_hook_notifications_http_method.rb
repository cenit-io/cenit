Mongoid.default_client.database.collection_names(filter: { name: /setup_notification_flows\Z/ }).each do |collection_name|
  collection = Mongoid.default_client[collection_name.to_s.to_sym]
  collection.find('_type' => 'Setup::WebHookNotification').each do |doc|
    next unless (m = doc['http_method'])
    collection.update_one(
      { _id: doc['_id'] },
      '$set' => { 'hook_method' => m },
      '$unset' => { 'http_method' => 1 }
    )
  end
end