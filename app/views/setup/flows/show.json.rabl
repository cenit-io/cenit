object @flow

node(:id){|e| e.id.to_s }
attributes :name, :purpose, :active

child(:connection_role, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name

  child(:connections, object_root: false) do  
    node(:id){|e| e.id.to_s }
    attributes :name, :url
  end
end

child(:data_type, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name
end

child(:webhook, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name, :path, :purpose
end

child(:event, object_root: false) do
  node(:id){|e| e.id.to_s }
  attributes :name
end

child(:schedule, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name, :period, :active
end

child(:batch, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :size
end
