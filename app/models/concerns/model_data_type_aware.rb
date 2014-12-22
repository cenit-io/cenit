module ModelDataTypeAware

  def data_type
    Setup::DataType.find_by(id: self.data_type_id) rescue nil
  end

end
