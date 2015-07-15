module Setup
  module CollectionName
    extend ActiveSupport::Concern

    included do

      field :name, type: String
      validates_format_of :name, with: /\A([a-z]|_)+\Z/
    end
  end
end