object @connection

node(:id){|e| e.id.to_s }
attributes :name, :url, :key, :token

child(:connection_roles, object_root: false) do
  node(:id){|e| e.id.to_s }
  attributes :name

  child(:webhooks, object_root: false) do
    node(:id){|e| e.id.to_s }
    attributes :name, :path, :purpose
  end  
end