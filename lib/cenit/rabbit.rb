require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def enqueue(message, &block)
        message = message.with_indifferent_access
        auto_retry =
          if message.has_key?(:auto_retry)
            message[:auto_retry]
          else
            Setup::Task.auto_retry_enum.first
          end
        scheduler = message.delete(:scheduler)
        publish_at = message.delete(:publish_at)
        asynchronous_message = (message.delete(:asynchronous) || scheduler || publish_at).present?
        task_class, task, report = detask(message)
        if task_class || task
          if task
            task_class = task.class
            if task.scheduler.present?
              scheduler = task.scheduler
            end
          else
            task = task_class.create(message: message, scheduler: scheduler, auto_retry: auto_retry)
          end
          task.update(auto_retry: auto_retry) unless task.auto_retry == auto_retry
          block.call(task) if block
          asynchronous_message ||= Cenit.send('asynchronous_' + task_class.to_s.split('::').last.underscore)
          task_execution = task.new_execution
          message[:execution_id] = task_execution.id.to_s
          if scheduler || publish_at || asynchronous_message
            tokens = TaskToken.where(task_id: task.id)
            if (token = message[:token])
              tokens = tokens.or(token: token)
            end
            tokens.delete_all
            message[:task_id] = task.id.to_s
            message = TaskToken.create(data: message.to_json,
                                       task: task,
                                       user: Cenit::MultiTenancy.user_model.current).token
            if (scheduler && scheduler.activated?) || (publish_at && publish_at > Time.now)
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
          task_execution
        else
          Setup::SystemNotification.create(message: report)
        end
      end

      def process_message(message, options = {})
        unless message.is_a?(Hash)
          message = JSON.parse(message) rescue { token: message }
        end
        message = message.with_indifferent_access
        message_token = message.delete(:token)
        if (token = TaskToken.where(token: message_token).first)
          token.destroy
          Cenit::MultiTenancy.user_model.current = token.user
          tenant = token.set_current_tenant
          message = JSON.parse(token.data).with_indifferent_access if token.data
        else
          tenant = nil
        end
        if Cenit::MultiTenancy.tenant_model.current.nil? ||
          (message_token.present? && Cenit::MultiTenancy.tenant_model.current != tenant)
          Setup::SystemReport.create(message: "Can not determine tenant for message: #{message}")
        else
          begin
            rabbit_consumer = nil
            task_class, task, report = detask(message)
            execution_id = message.delete(:execution_id)
            if options[:unscheduled.to_s]
              task.unschedule if task
            else
              task ||= task_class && task_class.create(message: message)
              if task
                if (rabbit_consumer = options[:rabbit_consumer] || RabbitConsumer.where(tag: options[:consumer_tag]).first)
                  rabbit_consumer.update(executor_id: tenant.id, task_id: task.id)
                end
                task.execute(execution_id: execution_id)
              else
                Setup::SystemNotification.create(message: report)
              end
            end
          rescue Exception => ex
            if task
              task.notify(ex)
            else
              Setup::SystemNotification.create(message: "Can not execute task for message: #{message}")
            end
          ensure
            rabbit_consumer.update(executor_id: nil, task_id: nil) if rabbit_consumer
          end
          if task && !task.resuming_manually? &&
            (task.resuming_later? ||
              ((scheduler = task.scheduler) && scheduler.activated?))
            message[:task] = task
            if (resume_interval = task.resume_interval)
              message[:publish_at] = Time.now + resume_interval
            end
            enqueue(message)
          end
        end
      rescue Exception => ex
        Setup::SystemReport.create(message: "Error (#{ex.message}) processing message: #{message}")
      end

      attr_reader :connection, :channel, :queue

      def init
        channel_mutex.lock
        if @connection.nil? || @channel.nil? || @channel.closed?
          unless @connection
            @connection =
              if (rabbit_url = ENV['RABBITMQ_BIGWIG_TX_URL']).present?
                Bunny.new(rabbit_url)
              else
                Bunny.new(automatically_recover: true,
                          user: Cenit.rabbit_mq_user,
                          password: Cenit.rabbit_mq_password)
              end
            connection.start
          end

          @channel ||= connection.create_channel
          @channel.open if @channel.closed?
          @channel.prefetch(1)

          @queue ||= @channel.queue(Cenit.rabbit_mq_queue)
        end
        true
      rescue Exception => ex
        Setup::SystemNotification.create(message: msg = "Error connecting with RabbitMQ: #{ex.message}")
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
                                                      tag: channel.generate_consumer_tag(Cenit.rabbit_mq_queue))
          new_consumer = queue.subscribe(consumer_tag: new_rabbit_consumer.tag, manual_ack: true) do |delivery_info, properties, body|
            consumer = delivery_info.consumer
            if (rabbit_consumer = RabbitConsumer.where(tag: consumer.consumer_tag).first)
              begin
                Cenit::MultiTenancy.tenant_model.current =
                  Cenit::MultiTenancy.user_model.current = nil
                Thread.clean_keys_prefixed_with('[cenit]')
                options = (properties[:headers] || {}).merge(rabbit_consumer: rabbit_consumer)
                Cenit::Rabbit.process_message(body, options)
              rescue Exception => ex
                Setup::SystemNotification.create(message: "Error (#{ex.message}) consuming message: #{body}")
              ensure
                Cenit::MultiTenancy.tenant_model.current =
                  Cenit::MultiTenancy.user_model.current = nil
                Thread.clean_keys_prefixed_with('[cenit]')
              end unless rabbit_consumer.cancelled?
            else
              Setup::SystemNotification.create(message: "Rabbit consumer with tag '#{consumer.consumer_tag}' not found")
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
        Setup::SystemNotification.create(message: "Error subscribing rabbit consumer: #{ex.message}")
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
                Setup::SystemNotification.create_with(message: "Error deleting delayed messages: #{ex.message}")
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
