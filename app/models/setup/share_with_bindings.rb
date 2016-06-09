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
  end
end