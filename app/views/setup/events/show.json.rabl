object @event

attributes :name, :triggers
child(:data_type, object_root: false) {attributes :name}