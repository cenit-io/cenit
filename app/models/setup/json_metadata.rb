module Setup
  module JsonMetadata
    extend ActiveSupport::Concern

    include HashField

    included do
      hash_field :metadata
    end
  end
end