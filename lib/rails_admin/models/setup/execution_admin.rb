module RailsAdmin
  module Models
    module Setup
      module ExecutionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do |c|
            navigation_label 'Monitors'
            weight 615
            object_label_method { :label }

            show_in_dashboard false
            c.configure :created_at

            c.configure :attachment, :storage_file

            c.configure :time_span, :time_span do
              metric :ms
            end

            c.configure :status, :enum do
              register_instance_option :enum do
                ::Setup::Task::STATUS
              end
            end

            c.configure :agent_id do
              pretty_value do
                if (agent_id = value) &&
                  (task = bindings[:object].task) &&
                  (agent = task.agent_model.where(id: agent_id).first)

                  v = bindings[:view]
                  amc = RailsAdmin.config(task.agent_model)
                  am = amc.abstract_model
                  wording = agent.send(amc.object_label_method)
                  can_see = !am.embedded? && (show_action = v.action(:show, am, agent))
                  (can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: agent_id), class: 'pjax') : wording).html_safe
                end
              end
            end

            list do
              field :agent_id
              field :created_at
              field :started_at
              field :time_span
              field :status
              field :attachment
              field :task
            end

            fields :created_at, :started_at, :time_span, :status, :attachment, :task, :notifications
          end
        end

      end
    end
  end
end
