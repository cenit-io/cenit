module Forms
  class SchedulerSelector
    include Mongoid::Document

    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: nil

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
    end
  end
end
