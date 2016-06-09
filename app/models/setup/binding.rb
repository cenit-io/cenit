module Setup
  class Binding
    include CenitScoped

    build_in_data_type

    deny :all
    allow :index

    belongs_to :connection, class_name: Setup::Connection.to_s, inverse_of: nil
    belongs_to :webhook, class_name: Setup::Webhook.to_s, inverse_of: nil
    belongs_to :authorization, class_name: Setup::Authorization.to_s, inverse_of: nil

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
        if (bind = where("#{object.class.to_s.split('::').last.downcase}_id" => object.id).first)
          bind[("#{model.to_s.split('::').last.downcase}_id")]
        end
      end

      def for(object, model)
        if (bind = where("#{object.class.to_s.split('::').last.downcase}_id" => object.id).first)
          bind.send(model.to_s.split('::').last.downcase)
        end
      end

      def bind(target, obj)
        where(target_id = "#{target.class.mongoid_root_class.to_s.split('::').last.downcase}_id" => target.id).delete_all
        create(target_id => target.id, "#{obj.class.mongoid_root_class.to_s.split('::').last.downcase}_id" => obj.id) if obj
      end
    end
  end
end