object @connection_role
attributes :name, :slug
child(:webhooks, object_root: false) {attributes :name, :slug, :path, :purpose}
child(:connections, object_root: false) {attributes :name, :slug, :url}