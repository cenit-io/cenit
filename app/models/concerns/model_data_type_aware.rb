module ModelDataTypeAware

  def data_type
    (data_type_id = try(:data_type_id)) && Setup::DataType.where(id: data_type_id).first
  end

end
