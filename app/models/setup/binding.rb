module Setup
  class Binding
    include CenitScoped

    build_in_data_type

    deny :all
    allow :index

    [
      Setup::Flow,
      Setup::Connection,
      Setup::Webhook,
      Setup::Authorization,
      Setup::Event,
      Setup::ConnectionRole
    ].each do |model|
      belongs_to model.to_s.split('::').last.underscore.to_sym, class_name: model.to_s, inverse_of: nil
    end

    def target
      @target || (relations.values.detect { |r| @target = send(r.name) } && @target)
    end

    def target_model
      target && target.class
    end

    def bind
      @bind ||
        (relations.values.to_a.reverse.detect { |r| @bind = send(r.name) } &&
          (@bind != target || (@bind = nil)) || @bind)
    end

    def bind_model
      bind && bind.class
    end

    class << self

      def id_for(object, model)
        if (bind = where("#{object.class.to_s.split('::').last.underscore}_id" => object.id).first)
          bind[("#{model.to_s.split('::').last.underscore}_id")]
        end
      end

      def for(object, model)
        if (bind = where("#{object.class.to_s.split('::').last.underscore}_id" => object.id).first)
          bind.send(model.to_s.split('::').last.underscore)
        end
      end

      def bind(target, obj, obj_model = nil)
        obj_model ||= obj.class
        obj_id = "#{obj_model.mongoid_root_class.to_s.split('::').last.underscore}_id".to_sym
        target_id = "#{target.class.mongoid_root_class.to_s.split('::').last.underscore}_id".to_sym
        where(target_id => target.id, obj_id.exists => true).delete_all
        create(target_id => target.id, obj_id => obj.id) if obj
      end
    end
  end
end