Tenant.all.each do |tenant|
  tenant.switch do
    Setup::Flow.all.each do |flow|
      flow.set_data_type_id
      Setup::Flow.collection.update_one(
        { _id: flow.id }, '$set' => { 'data_type_id' => flow.data_type_id }
      )
    end
  end
end