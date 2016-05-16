module Forms
  class SchedulerSelector
    include Mongoid::Document

    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: nil

    attr_accessor :target_task

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      field :scheduler do
        associated_collection_scope do
          task = bindings[:object].target_task
          Proc.new { |scope| task ? scope.where(origin: task.origin) : scope }
        end
      end
    end
  end
end
