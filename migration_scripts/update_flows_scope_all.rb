Mongoid.default_client.database.collection_names(filter: { name: /setup_flows\Z/ }).each do |collection_name|
  collection = Mongoid.default_client[collection_name.to_s.to_sym]
  flows_ids = collection.find.select do |flow|
    (flow['data_type_scope'] || '').start_with?('All')
  end.map do |flow|
    flow['_id']
  end
  collection.update_many(
    { _id: { '$in' => flows_ids } },
    '$set' => { 'data_type_scope' => 'All' }
  )
end