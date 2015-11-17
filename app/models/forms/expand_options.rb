module Forms
  class ExpandOptions
    include Mongoid::Document

    field :segment_shortcuts, type: Boolean

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
    end
  end
end
