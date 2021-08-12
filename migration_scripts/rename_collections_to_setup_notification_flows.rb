Mongoid.default_client.database.collection_names(filter: { name: /setup_notifications\Z/ }).each do |collection_name|
  collection = Mongoid.default_client[collection_name.to_s.to_sym]
  new_name = collection_name.to_s.gsub(/setup_notifications\Z/, 'setup_notification_flows')
  Mongoid.default_client.use(:admin).command(
    renameCollection: "#{collection.database.name}.#{collection.name}",
    to: "#{collection.database.name}.#{new_name}"
  )
end