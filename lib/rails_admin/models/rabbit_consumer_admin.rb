module RailsAdmin
  module Models
    module RabbitConsumerAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 850
          navigation_label 'Administration'
          visible { ::User.current_super_admin? }
          object_label_method { :to_s }

          configure :task_id do
            pretty_value do
              if (executor = (obj = bindings[:object]).executor) && (task = obj.executing_task)
                v = bindings[:view]
                amc = RailsAdmin.config(task.class)
                am = amc.abstract_model
                wording = task.send(amc.object_label_method)
                amc = RailsAdmin.config(Account)
                am = amc.abstract_model
                if (inspect_action = v.action(:inspect, am, executor))
                  task_path = v.show_path(model_name: task.class.to_s.underscore.gsub('/', '~'), id: task.id.to_s)
                  v.link_to(wording, v.url_for(action: inspect_action.action_name, model_name: am.to_param, id: executor.id, params: { return_to: task_path }))
                else
                  wording
                end.html_safe
              end
            end
          end

          list do
            field :channel
            field :tag
            field :executor
            field :task_id
            field :alive
            field :updated_at
          end

          fields :created_at, :channel, :tag, :executor, :task_id, :alive, :created_at, :updated_at

        end
      end

    end
  end
end
