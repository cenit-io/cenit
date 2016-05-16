module Forms
  class CrossOriginSelector
    include Mongoid::Document

    field :origin, type: Symbol, default: :default

    validates_presence_of :origin

    attr_accessor :target_model

    def origin_enum
      [:default] + ((target_model && target_model.origins) || CrossOrigin.names)
    end

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
    end

  end
end
