module Setup
  class FlowExecution < Setup::Task

    agent_field :flow

    build_in_data_type

    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    before_save do
      self.flow = Setup::Flow.where(id: message['flow_id']).first
    end

    def sources
      (flow && flow.sources(message)) || []
    end

    def cyclic_execution(execution_graph, start_id, cycle = [])
      if cycle.include?(start_id)
        cycle << start_id
        return cycle
      elsif (adjacency_list = execution_graph[start_id])
        cycle << start_id
        adjacency_list.each { |id| return cycle if cyclic_execution(execution_graph, id, cycle) }
        cycle.pop
      end
      false
    end

    def run(message)
      if (flow = Setup::Flow.where(id: (flow_id = message[:flow_id])).first)
        if flow.active
          unless (execution_graph = message[:execution_graph])
            execution_graph = message[:execution_graph] = {}
          end
          if (cycle = cyclic_execution(execution_graph, flow_id.to_s))
            cycles = execution_graph['cycles'] = (execution_graph['cycles'] || 0) + 1
            cycle = cycle.collect { |id| ((flow = Setup::Flow.where(id: id).first) && flow.custom_title) || id }
            notify(
              message: "Cyclic flow execution detected (#{cycles}): #{cycle.to_a.join(' -> ')}",
              attachment: {
                filename: 'execution_graph.json',
                contentType: 'application/json',
                body: JSON.pretty_generate(execution_graph)
              },
              type: :warning
            )
            if cycles > Cenit.maximum_cyclic_flow_executions
              resume_manually
              if scheduler
                notify(
                  message: "Detached from scheduler #{scheduler.custom_title} due to overflow cyclic executions",
                  type: :warning
                )
                self.scheduler = nil
              end
              fail "Too many cyclic flow executions (#{cycles})"
            end
          end
          flow.translate(message.merge(task: self)) { |notification_data| notify(notification_data) }
        else
          fail Setup::Task::Broken, "Flow '#{flow.custom_title}' is not active and can not be processed"
        end
      else
        fail "Flow with id #{flow_id} not found"
      end
    end

  end
end
