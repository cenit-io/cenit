object @webhook

attributes :name, :slug, :path, :purpose
child(:connection_roles, object_root: false) do 
  attributes :name
  child(:connections, object_root: false){ attributes :name, :url} 
end
child(:data_type, object_root: false) {attributes :name, :slug}
child(:data_type_response, object_root: false) {attributes :name, :slug}
child(:url_parameters, object_root: false) {attributes :key, :value}
child(:headers, object_root: false) {attributes :key, :value}
