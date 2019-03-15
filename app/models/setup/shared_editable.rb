module Setup
  module SharedEditable
    extend ActiveSupport::Concern

    include CrossOriginShared

    included do
      shared_allow :edit
    end

  end
end
