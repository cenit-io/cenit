Mongoid.default_client.database.collection_names(filter: { name: /setup_algorithms\Z/ }).each do |collection_name|
  collection = Mongoid.default_client[collection_name.to_s.to_sym]
  collection.find.each do |alg|
    if (parameters = alg['parameters'])
      update = false
      new_params = []
      parameters.each do |param|
        new_params <<
          if param['type'] == 'hash'
            update = true
            param.merge('type' => 'object')
          else
            param
          end
      end
      next unless update
      collection.update_one(
        { _id: alg['_id'] },
        '$set' => { 'parameters' => new_params }
      )
    end
  end
end