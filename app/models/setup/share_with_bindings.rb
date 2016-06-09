module Setup
  module ShareWithBindings
    extend ActiveSupport::Concern

    include CrossOriginShared
    include Bindings

    def save(options = {})
      if shared? && User.current != creator
        valid? && bind_bindings
        errors.blank?
      else
        super
      end
    end

    module ClassMethods

      def tracked_field?(field, action = :update)
        field = field.to_s
        binds.none? { |r| r.foreign_key.to_s == field } && super
      end

    end
  end
end