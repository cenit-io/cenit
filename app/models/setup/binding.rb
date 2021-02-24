module Setup
  class Binding
    include CenitScoped

    build_in_data_type.and(
      properties: {
        binder_data_type: {
          referenced: true,
          '$ref': {
            namespace: 'Setup',
            name: 'DataType'
          },
          edi: {
            discard: true
          },
          virtual: true
        },
        binder: {
          type: 'object',
          edi: {
            discard: true
          },
          virtual: true
        },
        bind_data_type: {
          referenced: true,
          '$ref': {
            namespace: 'Setup',
            name: 'DataType'
          },
          edi: {
            discard: true
          },
          virtual: true
        },
        bind: {
          type: 'object',
          edi: {
            discard: true
          },
          virtual: true
        }
      }
    )

    deny :create

    bind_models =
      [
        Setup::Authorization,
        Setup::Event,
        Setup::ConnectionRole,
        Setup::Snippet
      ]

    bind_models.each do |model|
      model.after_destroy do
        Setup::Binding.where(Binding.bind_id(self) => id).delete_all
      end
    end

    {
      binder:
        [
          Setup::Flow,
          Setup::Connection,
          Setup::Webhook,
          Setup::Algorithm,
          Setup::Translator,
          Setup::DataType,
          Setup::Validator
        ],
      bind: bind_models
    }.each do |role, models|
      models.each do |model|
        belongs_to "#{model.to_s.split('::').last.underscore}_#{role}".to_sym, class_name: model.to_s, inverse_of: nil
      end
    end

    def binder
      @binder || (relations.values.detect { |r| r.name.to_s.ends_with?('binder') && (@binder = send(r.name)) } && @binder)
    end

    def binder_model
      binder&.class
    end

    def binder_data_type
      binder_model&.data_type
    end

    def bind
      @bind || (relations.values.to_a.reverse.detect { |r| r.name.to_s.ends_with?('bind') && (@bind = send(r.name)) } && @bind)
    end

    def bind_model
      bind&.class
    end

    def bind_data_type
      bind_model&.data_type
    end

    def label
      "#{bind.class.to_s.split('::').last} of #{((b = binder) && b.custom_title)}"
    end

    class << self
      def bind_bind_id_for(binder, bind_model)
        bind_id = bind_id(bind_model)
        bind = where(binder_id(binder) => binder.id, bind_id.to_sym.exists => true).first
        [bind, bind_id]
      end

      def id_for(binder, bind_model)
        bind_id = bind_id(bind_model)
        if (bind = where(binder_id(binder) => binder.id,
                         bind_id.to_sym.exists => true).first)
          bind[bind_id]
        end
      end

      def for(binder, bind_model)
        if (bind = where(binder_id(binder) => binder.id,
                         bind_id(bind_model).to_sym.exists => true).first)
          bind.send(bind_model.to_s.split('::').last.underscore)
        end
      end

      def bind(binder, bind, bind_model = nil)
        bind_model ||= bind.class
        obj_id, binder_id = bind_id(bind_model), binder_id(binder)
        where(binder_id => binder.id, obj_id.to_sym.exists => true).delete_all
        create(binder_id => binder.id, obj_id => bind.id) if bind
      end

      def clear(binder, ids = nil)
        if ids
          where(binder_id(binder).to_sym.in => ids)
        else
          where(binder_id(binder) => binder.id)
        end.delete_all
      end

      def bind_id(bind)
        bind = bind.class unless bind.is_a?(Class)
        "#{bind.mongoid_root_class.to_s.split('::').last.underscore}_bind_id"
      end

      def binder_id(binder)
        binder = binder.class unless binder.is_a?(Class)
        "#{binder.mongoid_root_class.to_s.split('::').last.underscore}_binder_id"
      end

      def stored_properties_on(record)
        stored = super
        %w(binder_data_type binder bind_data_type bind).each { |prop| stored << prop }
        stored
      end
    end
  end
end
