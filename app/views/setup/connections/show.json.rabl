object @connection
attributes :name, :slug, :url, :key, :token
child(:connection_roles, object_root: false) do
  attributes :name, :slug
  child(:webhooks, object_root: false) {attributes :name, :slug, :path, :purpose}
end