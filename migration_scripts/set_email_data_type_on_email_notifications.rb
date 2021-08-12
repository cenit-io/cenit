default_email_data_type_id = Setup::Configuration.email_data_type_id
Mongoid.default_client.database.collection_names(filter: { name: /setup_notification_flows\Z/ }).each do |collection_name|
  collection = Mongoid.default_client[collection_name.to_s.to_sym]
  filter = {
    '_type' => 'Setup::EmailNotification',
    'email_data_type_id' => { '$exists' => false }
  }
  collection.update_many(filter, '$set' => {
    'email_data_type_id' => default_email_data_type_id
  })
end