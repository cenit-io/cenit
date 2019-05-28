module Setup
  class Pin
    include CenitScoped
    include DynamicValidators

    build_in_data_type

    deny :all
    allow :index, :show, :delete

    field :target_model_name, type: String
    field :target_id

    belongs_to :trace, class_name: ::Mongoid::Tracer::Trace.to_s, inverse_of: nil

    validates_presence_of :trace

    before_save do
      self.target_model_name = trace.target_model.mongoid_root_class.to_s
      self.target_id = trace.target_id
      errors.blank?
    end

    delegate :target_model, :target, to: :trace, allow_nil: true

    class << self

      def for(object)
        where(target_model_name: object.class.mongoid_root_class.to_s, target_id: object.id).first
      end

    end
  end
end
