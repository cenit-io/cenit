object @flows

attributes :name, :slug, :purpose, :active, :batch
child(:connection_role, object_root: false) do 
  attributes :name, :slug
  child(:connections, object_root: false){ attributes :name, :slug, :url} 
end
child(:data_type, object_root: false) {attributes :name, :slug }
child(:webhook, object_root: false) {attributes :name, :slug, :path, :purpose}
child(:event, object_root: false) {attributes :name}
child(:schedule, object_root: false) {attributes :name, :period, :active} 
child(:batch, object_root: false) {attributes :size}