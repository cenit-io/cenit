require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def enqueue(message)
        message = message.with_indifferent_access
        asynchronous_message = message.delete(:asynchronous).present? |
          (scheduler = message.delete(:scheduler)).present? |
          (publish_at = message.delete(:publish_at))
        task_class, task, report = detask(message)
        if task_class || task
          if task
            task_class = task.class
            if task.scheduler.present?
              scheduler = task.scheduler
            end
          else
            task = task_class.create(message: message, scheduler: scheduler)
            task.save
          end
          asynchronous_message ||= Cenit.send('asynchronous_' + task_class.to_s.split('::').last.underscore)
          if scheduler || publish_at || asynchronous_message
            if (token = message[:token]) && token = AccountToken.where(token: token).first
              token.destroy
            end
            message[:token] = AccountToken.create.token
            message[:task_id] = task.id.to_s
            message = message.to_json
            if scheduler || publish_at
              Setup::DelayedMessage.create(message: message, publish_at: publish_at, scheduler: scheduler)
            else
              channel_mutex.lock
              channel.default_exchange.publish(message, routing_key: queue.name)
              channel_mutex.unlock
            end
          else
            message[:task] = task
            process_message(message)
          end
          task
        else
          Setup::Notification.create(message: report)
        end
      end

      def process_message(message, headers = {})
        message = JSON.parse(message) unless message.is_a?(Hash)
        message = message.with_indifferent_access
        message_token = message.delete(:token)
        if token = AccountToken.where(token: message_token).first
          account = token.set_current_account
          token.destroy
        else
          account = nil
        end
        if Account.current.nil? || (message_token.present? && Account.current != account)
          Setup::Notification.create(message: "Can not determine account for message: #{message}")
        else
          begin
            task_class, task, report = detask(message)
            if headers[:unscheduled.to_s]
              task.unschedule if task
            else
              if task ||= task_class && task_class.create(message: message)
                task.execute
              else
                Setup::Notification.create(message: report)
              end
            end
          rescue Exception => ex
            if task
              task.notify(message: ex.message)
            else
              Setup::Notification.create(message: "Can not execute task for message: #{message}")
            end
          end
          if task && (task.resuming_later? || ((scheduler = task.scheduler) && scheduler.activated?))
            message[:task] = task
            if resume_interval = task.resume_interval
              message[:publish_at] = Time.now + resume_interval
            end
            enqueue(message)
          end
        end
      rescue Exception => ex
        Setup::Notification.create(message: "Error (#{ex.message}) processing message: #{message}")
      end

      attr_reader :connection, :channel, :queue, :channel_mutex

      def init
        unless @connection
          @connection = Bunny.new(automatically_recover: true)
          @connection.start

          @channel = @connection.create_channel
          @queue = @channel.queue('cenit')
          @channel.prefetch(1)

          @channel_mutex = Mutex.new
        end
      end

      def close
        if connection
          connection.close
        end
      end

      def start_consumer
        init
        queue.subscribe(manual_ack: true) do |delivery_info, properties, body|
          begin
            Account.current = nil
            Cenit::Rabbit.process_message(body, properties[:headers] || {})
            channel.ack(delivery_info.delivery_tag)
          rescue Exception => ex
            Setup::Notification.create(message: "Error (#{ex.message}) consuming message: #{body}")
          ensure
            Account.current = nil
          end
        end
        puts 'RABBIT CONSUMER STARTED'
      rescue Exception => ex
        Setup::Notification.create(message: "Error subscribing rabbit consumer: #{ex.message}")
      end

      def start_scheduler
        init
        @scheduler_job = Rufus::Scheduler.new.interval "#{Cenit.scheduler_lookup_interval}s" do
          messages_present = false
          (delayed_messages = Setup::DelayedMessage.all.or(:publish_at.lte => Time.now).or(unscheduled: true)).each do |delayed_message|
            publish_options = {routing_key: queue.name}
            publish_options[:headers] = {unscheduled: true} if delayed_message.unscheduled
            channel.default_exchange.publish(delayed_message.message, publish_options)
            messages_present = true
          end
          begin
            delayed_messages.destroy_all
          rescue Exception => ex
            puts "Error deleting delayed messages: #{ex.message}"
          end if messages_present
        end
        puts 'RABBIT SCHEDULER STARTED'
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
