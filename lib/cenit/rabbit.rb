require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def enqueue(message)
        message = message.with_indifferent_access
        task_class, task, report = detask(message)
        if task_class
          task ||= task_class.create(message: message)
          if Cenit.send('asynchronous_' + task_class.to_s.split('::').last.underscore)
            message[:task_id] = task.id.to_s
            message[:token] = CenitToken.create(data: {account_id: Account.current.id.to_s}).token
            conn = Bunny.new(automatically_recover: false)
            conn.start
            ch = conn.create_channel
            q = ch.queue('cenit')
            ch.default_exchange.publish(message.to_json, routing_key: q.name)
            conn.close
          else
            message[:task] = task
            process_message(message)
          end
        else
          Setup::Notification.create(message: report)
        end
      end

      def process_message(message)
        message = JSON.parse(message) unless message.is_a?(Hash)
        message = message.with_indifferent_access
        message_token = message.delete(:token)
        if token = CenitToken.where(token: message_token).first
          if account = Account.where(id: token.data[:account_id]).first
            Account.current = account if Account.current.nil?
          end
          token.destroy
        else
          account = nil
        end
        if Account.current.nil? || (message_token.present? && Account.current != account)
          Setup::Notification.create(message: "Invalid message #{message}")
        else
          begin
            task_class, task, report = detask(message)
            if task ||= task_class && task_class.create(message: message)
              if task.status == :running
                task.notify(message: "Can't be executed because is already running")
              else
                task.execute
              end
            else
              Setup::Notification.create(message: report)
            end
          rescue Exception => ex
            if task
              task.notify(message: ex.message)
            else
              Setup::Notification.create(message: "Can not execute task for message: #{message}")
            end
          end
        end
      end

      private

      def detask(message)
        report = nil
        case task = message.delete(:task)
        when Class
          task_class = task
          task = nil
        when Setup::Task
          task_class = task.class
        when String
          unless task_class = task.constantize rescue nil
            report = "Invalid task class name: #{task}"
          end
          task = nil
        else
          task_class = nil
          if task
            report = "Invalid task argument: #{task}"
            task = nil
          elsif id = message.delete(:task_id)
            if task = Setup::Task.where(id: id).first
              task_class = task.class
            else
              report = "Task with ID '#{id}' not found"
            end
          else
            report = 'Task information is missing'
          end
        end
        [task_class, task, report]
      end
    end
  end
end
