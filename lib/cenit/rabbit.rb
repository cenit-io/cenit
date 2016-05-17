require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def enqueue(message, &block)
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
          block.call(task) if block
          asynchronous_message ||= Cenit.send('asynchronous_' + task_class.to_s.split('::').last.underscore)
          if scheduler || publish_at || asynchronous_message
            if (token = message[:token]) && (token = AccountToken.where(token: token).first)
              token.destroy
            end
            message[:task_id] = task.id.to_s
            message = AccountToken.create(data: message.to_json).token
            if scheduler || publish_at
              Setup::DelayedMessage.create(message: message, publish_at: publish_at, scheduler: scheduler)
            else
              unless task.joining?
                channel_mutex.lock
                if channel.closed?
                  Setup::DelayedMessage.create(message: message)
                else
                  channel.default_exchange.publish(message, routing_key: queue.name)
                end
                channel_mutex.unlock
              end
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

      def process_message(message, options = {})
        unless message.is_a?(Hash)
          message = JSON.parse(message) rescue { token: message }
        end
        message = message.with_indifferent_access
        message_token = message.delete(:token)
        if (token = AccountToken.where(token: message_token).first)
          account = token.set_current_account
          message = JSON.parse(token.data).with_indifferent_access if token.data
          token.destroy
        else
          account = nil
        end
        if Account.current.nil? || (message_token.present? && Account.current != account)
          Setup::Notification.create(message: "Can not determine account for message: #{message}")
        else
          begin
            rabbit_consumer = nil
            task_class, task, report = detask(message)
            if options[:unscheduled.to_s]
              task.unschedule if task
            else
              if task ||= task_class && task_class.create(message: message)
                if (rabbit_consumer = options[:rabbit_consumer] || RabbitConsumer.where(tag: options[:consumer_tag]).first)
                  rabbit_consumer.update(executor_id: account.id, task_id: task.id)
                end
                task.execute
              else
                Setup::Notification.create(message: report)
              end
            end
          rescue Exception => ex
            if task
              task.notify(ex)
            else
              Setup::Notification.create(message: "Can not execute task for message: #{message}")
            end
          ensure
            rabbit_consumer.update(executor_id: nil, task_id: nil) if rabbit_consumer
          end
          if task && (task.resuming_later? || ((scheduler = task.scheduler) && scheduler.activated?))
            message[:task] = task
            if (resume_interval = task.resume_interval)
              message[:publish_at] = Time.now + resume_interval
            end
            enqueue(message)
          end
        end
      rescue Exception => ex
        Setup::Notification.create(message: "Error (#{ex.message}) processing message: #{message}")
      end

      attr_reader :connection, :channel, :queue

      def init
        channel_mutex.lock
        if @connection.nil? || @channel.nil? || @channel.closed?
          unless @connection
            @connection = Bunny.new(automatically_recover: true,
                                    user: Cenit.rabbit_mq_user,
                                    password: Cenit.rabbit_mq_password)
            connection.start
          end

          @channel ||= connection.create_channel
          @channel.open if @channel.closed?
          @channel.prefetch(1)

          @queue ||= @channel.queue('cenit')
        end
        true
      rescue Exception => ex
        Setup::Notification.create(message: msg = "Error connecting with RabbitMQ: #{ex.message}")
        puts msg
        false
      ensure
        channel_mutex.unlock
      end

      def channel_mutex
        @channel_mutex ||= Mutex.new
      end

      def close
        if connection
          connection.close
          @connection = nil
        end
      end

      def start_consumer
        if init
          new_rabbit_consumer = RabbitConsumer.create(channel: "#{connection.host}:#{connection.local_port} (#{channel.id})",
                                                      tag: channel.generate_consumer_tag('cenit'))
          new_consumer = queue.subscribe(consumer_tag: new_rabbit_consumer.tag, manual_ack: true) do |delivery_info, properties, body|
            consumer = delivery_info.consumer
            if (rabbit_consumer = RabbitConsumer.where(tag: consumer.consumer_tag).first)
              begin
                Account.current = nil
                options = (properties[:headers] || {}).merge(rabbit_consumer: rabbit_consumer)
                Cenit::Rabbit.process_message(body, options)
              rescue Exception => ex
                Setup::Notification.create(message: "Error (#{ex.message}) consuming message: #{body}")
              ensure
                Account.current = nil
              end unless rabbit_consumer.cancelled?
            else
              Setup::Notification.create(message: "Rabbit consumer with tag '#{consumer.consumer_tag}' not found")
            end
            channel.reject(delivery_info.delivery_tag, true) unless rabbit_consumer && !rabbit_consumer.cancelled?
            channel.ack(delivery_info.delivery_tag)
            channel_mutex.lock #channel might be closed
            consumer.cancel if rabbit_consumer && rabbit_consumer.cancelled?
            channel_mutex.unlock
          end
          puts "RABBIT CONSUMER '#{new_consumer.consumer_tag}' STARTED"
        end
      rescue Exception => ex
        Setup::Notification.create(message: "Error subscribing rabbit consumer: #{ex.message}")
      end

      def start_scheduler
        if init
          @scheduler_job = Rufus::Scheduler.new.interval "#{Cenit.scheduler_lookup_interval}s" do
            channel_mutex.lock
            unless channel.closed?
              messages_present = false
              (delayed_messages = Setup::DelayedMessage.all.or(:publish_at.lte => Time.now).or(unscheduled: true)).each do |delayed_message|
                publish_options = { routing_key: queue.name }
                publish_options[:headers] = { unscheduled: true } if delayed_message.unscheduled
                channel.default_exchange.publish(delayed_message.message, publish_options)
                messages_present = true
              end
              begin
                delayed_messages.destroy_all
              rescue Exception => ex
                Setup::Notification.create_with(message: "Error deleting delayed messages: #{ex.message}")
              end if messages_present
            end
            channel_mutex.unlock
          end
          puts 'RABBIT SCHEDULER STARTED'
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
          task_class = task.constantize rescue nil
          report = "Invalid task class name: #{task}" unless task_class
          task = nil
        else
          task_class = nil
          if task
            report = "Invalid task argument: #{task}"
            task = nil
          elsif (id = message.delete(:task_id))
            if (task = Setup::Task.where(id: id).first)
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
