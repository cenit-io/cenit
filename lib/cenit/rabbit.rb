require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def enqueue(message)
        message = message.with_indifferent_access
        scheduler = message.delete(:scheduler)
        asynchronous_message = scheduler.present? | message.delete(:asynchronous)
        task_class, task, report = detask(message)
        if task_class || task
          if task
            if task.scheduler.present?
              scheduler = task.scheduler
              asynchronous_message = true
            end
          else
            task = task_class.create(message: message, scheduler: scheduler)
            task.save
          end
          if asynchronous_message || Cenit.send('asynchronous_' + task_class.to_s.split('::').last.underscore)
            message[:task_id] = task.id.to_s
            q =
              if scheduler.present?
                message[:scheduler_id] = scheduler.id.to_s
                message[:publish_at] = scheduler.next_time
                scheduler_queue
              else
                queue
              end
            if token = message[:token]
              CenitToken.where(token: token).delete_all
            end
            message[:token] = CenitToken.create(data: {account_id: Account.current.id.to_s}).token
            channel_mutex.lock
            channel.default_exchange.publish(message.to_json, routing_key: q.name)
            channel_mutex.unlock
          else
            message[:task] = task
            process_message(message)
          end
          task
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
          Setup::Notification.create(message: "Can not determine account for message: #{message}")
        else
          begin
            task_class, task, report = detask(message)
            if task ||= task_class && task_class.create(message: message)
              task.execute
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
          if task && (scheduler = task.scheduler) && scheduler.activated?
            message[:task] = task
            enqueue(message)
          end
        end
      rescue Exception => ex
        Setup::Notification.create(message: "Error (#{ex.message}) processing message: #{message}")
      end

      attr_reader :connection, :channel, :queue, :scheduler_queue, :channel_mutex

      def init
        unless @connection
          @connection = Bunny.new(automatically_recover: true)
          @connection.start

          @channel = @connection.create_channel
          @queue = @channel.queue('cenit')
          @scheduler_queue = @channel.queue('cenit_scheduler')
          @channel.prefetch(1)

          @channel_mutex = Mutex.new
        end
      end

      def start_consumer
        init
        queue.subscribe(manual_ack: true) do |delivery_info, properties, body|
          begin
            Cenit::Rabbit.process_message(body)
            channel.ack(delivery_info.delivery_tag)
          rescue Exception => ex
            Setup::Notification.create(message: "Error (#{ex.message}) consuming message: #{body}")
          end
        end
        puts 'RABBIT CONSUMER STARTED'
      rescue Exception => ex
        Setup::Notification.create(message: "Error subscribing rabbit consumer: #{ex.message}")
      end

      def start_scheduler
        init
        scheduler_queue.subscribe(manual_ack: true) do |delivery_info, properties, body|
          begin
            body_hash = JSON.parse(body)
            if (token = CenitToken.where(token: body_hash[:token.to_s]).first) &&
              (account = Account.where(id: token.data[:account_id]).first)
              Account.current = account
              scheduler_id = body_hash.delete(:scheduler_id.to_s)
              publish_at = Time.parse(body_hash.delete(:publish_at.to_s))
              if scheduler_id.nil? || Setup::Scheduler.where(id: scheduler_id).present?
                Setup::DelayedMessage.create!(message: body_hash.to_json, publish_at: publish_at, scheduler_id: scheduler_id, token: body_hash[:token.to_s])
              end
            end
          rescue Exception => ex
            puts ex.backtrace
            puts "Error (#{ex.message}) consuming message: #{body}"
          ensure
            channel.ack(delivery_info.delivery_tag)
          end
        end

        @scheduler_job = Rufus::Scheduler.new.interval "#{Cenit.scheduler_lookup_interval}s" do
          (delayed_messages = Setup::DelayedMessage.where(:publish_at.lte => Time.now)).each do |delayed_message|
            if (token = CenitToken.where(token: delayed_message.token).first) &&
              (account = Account.where(id: token.data[:account_id]).first)
              Thread.current[:current_account] = account
              if delayed_message.scheduler_id.nil? || Setup::Scheduler.where(id: delayed_message.scheduler_id).present?
                channel.default_exchange.publish(msg, routing_key: queue.name)
              end
            end
          end
          delayed_messages.delete_all if delayed_messages.present?
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
