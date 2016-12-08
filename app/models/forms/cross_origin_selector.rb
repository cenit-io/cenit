module Forms
  class CrossOriginSelector
    include Mongoid::Document

    field :origin, type: Symbol

    validates_presence_of :origin

    attr_accessor :target_model

    def origin_enum
      (target_model.try(:origins) || CrossOrigin.names).reject { |origin| Setup::Crossing.authorized_crossing_origins.exclude?(origin) }
    end

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
    end

  end
end
