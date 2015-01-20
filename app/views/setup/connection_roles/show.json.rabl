object @connection_role

node(:id){|e| e.id.to_s }
attributes :name

child(:webhooks, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name, :path, :purpose
end  

child(:connections, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name, :url
end  