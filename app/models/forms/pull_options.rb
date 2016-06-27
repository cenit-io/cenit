module Forms
  class PullOptions
    include Mongoid::Document

    field :auto_fill, type: Boolean
    field :pause_on_update, type: Boolean, default: true
    field :halt_on_error, type: Boolean, default: true

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      configure :auto_fill do
        label 'Automatically fill parameters'
      end
    end
  end
end