object @event

node(:id){|e| e.id.to_s }
attributes :name, :triggers

child(:data_type, object_root: false) do 
  node(:id){|e| e.id.to_s }
  attributes :name
end