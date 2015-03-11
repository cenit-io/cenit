object @template

node(:id){|e| e.id.to_s }
attributes :name

child(:library, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name
end  

child(:connection_role, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name
end  

child(:connections, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name, :url
end  

child(:webhooks, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name, :path, :purpose
end  

child(:flows, object_root: false) do 
  attributes :name, :url
end  