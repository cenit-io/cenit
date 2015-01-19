object @template
attributes :name, :slug
child(:library, object_root: false) {attributes :name, :slug}
child(:connection_role, object_root: false)  {attributes :name, :slug}
child(:connections, object_root: false) {attributes :name, :slug, :url}
child(:webhooks, object_root: false) {attributes :name, :slug, :path, :purpose}
child(:flows, object_root: false) {attributes :name, :slug, :url}