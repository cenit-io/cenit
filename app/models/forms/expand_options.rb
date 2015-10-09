module Forms
  class ExpandOptions
    include Mongoid::Document

    field :segment_shortcuts, type: Boolean

    rails_admin do
      visible false
    end
  end
end
