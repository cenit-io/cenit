object @webhook

node(:id){|e| e.id.to_s }
attributes :name, :path, :purpose

child(:connection_roles, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name
  
  child(:connections, object_root: false) do
    node(:id){|e| e.id.to_s }
    attributes :name 
  end
end

child(:data_type, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name
end

child(:data_type_response, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name
end

child(:url_parameters, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :key, :value
end

child(:headers, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :key, :value
end
