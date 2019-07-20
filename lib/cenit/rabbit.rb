require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def maximum_active_tasks
        @maximum__active_tasks ||= 50 * (ENV['UNICORN_CENIT_SERVER'].to_b ? Cenit.maximum_unicorn_consumers : 1)
      end

      def tasks_quota(active_tenants = nil)
        active_tenants ||= ActiveTenant.active_count
        quota = maximum_active_tasks / (active_tenants > 0 ? active_tenants : 1)
        quota < 1 ? 1 : quota
      end

      def enqueue(message, &block)
        message = message.with_indifferent_access
        auto_retry = message[:auto_retry].presence || Setup::Task.auto_retry_enum.first
        scheduler = message.delete(:scheduler)
        publish_at = message.delete(:publish_at)
        async_message = (message.delete(:asynchronous) || scheduler || publish_at).present?
        task_class, task, report = detask(message)
        if task_class || task
          if task
            task_class = task.class
            if task.scheduler.present?
              scheduler = task.scheduler
            end
          else
            task = task_class.create(message: message, scheduler: scheduler, auto_retry: auto_retry)
            unless task.persisted?
              return Setup::SystemNotification.create(message: "Task instance for #{task_class} could not be persisted: #{task.errors.full_messages.to_sentence}")
            end
          end
          if TaskToken.where(task_id: task.id).exists?
            Setup::SystemNotification.create(message: "Task #{task} already onboard, skipping requeuing (task ID: #{task.id})!", type: :warning)
          else
            task.update(auto_retry: auto_retry) unless task.auto_retry == auto_retry
            block.call(task) if block
            task_execution = task.queue_execution
            unless task.joining?
              async_message ||= !Cenit.send('synchronous_' + task_class.to_s.split('::').last.underscore)
              message[:execution_id] = task_execution.id.to_s
              if scheduler || publish_at || async_message
                if (token = message[:token])
                  TaskToken.where(token: token).delete_all
                end
                message[:task_id] = task.id.to_s
                token = TaskToken.create(
                  data: message.to_json,
                  task: task,
                  user: Cenit::MultiTenancy.user_model.current
                )
                message = token.token
                if scheduler&.activated? || (publish_at && publish_at > Time.now) || ActiveTenant.tasks_for_current > tasks_quota
                  Setup::DelayedMessage.create(message: message, publish_at: publish_at, scheduler: scheduler)
                else
                  begin
                    channel_mutex.lock
                    if channel.nil? || channel.closed?
                      Setup::DelayedMessage.create(message: message)
                    else
                      ActiveTenant.inc_tasks_for_current
                      channel.default_exchange.publish(message, routing_key: queue.name)
                    end
                  ensure
                    channel_mutex.unlock
                  end
                end
              else
                message[:task] = task
                process_message(message)
              end
            end
            task_execution
          end
        else
          Setup::SystemNotification.create(message: report)
        end
      end

      def process_message(message, options = {})
        unless message.is_a?(Hash)
          message =
            begin
              JSON.parse(message)
            rescue
              { token: message }
            end
        end
        tenant = token = nil
        message = message.with_indifferent_access
        if (message_token = message.delete(:token))
          if (token = TaskToken.where(token: message_token).first)
            tenant = token.set_current_tenant!
            unless (Cenit::MultiTenancy.user_model.current = token.user)
              if tenant
                Cenit::MultiTenancy.user_model.current = tenant.owner
                Setup::SystemReport.create(message: "No token user, using tenant #{tenant.label} owner (task ##{token.task_id})", type: :warning)
              end
            end
            ActiveTenant.dec_tasks_for(tenant)
            message = JSON.parse(token.data).with_indifferent_access if token.data
          else
            Setup::SystemReport.create(message: "No task token for #{message_token}")
            tenant = nil
          end
        end
        if Cenit::MultiTenancy.tenant_model.current.nil?
          Setup::SystemReport.create(message: "Can not determine tenant for message: #{message} (token #{message_token})")
          Setup::SystemReport.create(message: message_token)
        elsif message_token.present? && Cenit::MultiTenancy.tenant_model.current != tenant
          msg = "Trying to execute on tenant #{Cenit::MultiTenancy.tenant_model.current.label}" +
                " but token tenant is #{tenant ? tenant.label : '<anonymous>'} (token: #{message_token}, message: #{message})"
          Setup::SystemReport.create(message: msg)
          Setup::SystemReport.create(message: message_token)
        else
          begin
            token.destroy if token
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
            reject = true
            if (rabbit_consumer = RabbitConsumer.where(tag: consumer.consumer_tag).first)
              begin
                reject = false
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
            if reject
              channel.reject(delivery_info.delivery_tag, true)
            else
              channel.ack(delivery_info.delivery_tag)
            end
            begin
              channel_mutex.lock #channel might be closed
              consumer.cancel if rabbit_consumer && rabbit_consumer.cancelled?
            ensure
              channel_mutex.unlock
            end
          end
          puts "RABBIT CONSUMER '#{new_consumer.consumer_tag}' STARTED"
        end
      rescue Exception => ex
        Setup::SystemNotification.create(message: "Error subscribing rabbit consumer: #{ex.message}")
      end

      def start_scheduler
        if init
          @scheduler_job = Rufus::Scheduler.new.interval "#{Cenit.scheduler_lookup_interval}s" do
            lookup_messages
          end
          puts 'RABBIT SCHEDULER STARTED'
        end
      end

      def lookup_messages(opts = {})
        channel_mutex.lock
        unless channel.closed?
          dispatched_ids = []
          tenant_tasks = {}
          ActiveTenant.each do |active_tenant|
            tenant_tasks[active_tenant[:tenant_id]] = active_tenant[:tasks]
          end
          quota = opts[:quota] || tasks_quota(tenant_tasks.size)

          delayed_message_digester = proc do |delayed_message|
            if (tenant = delayed_message.tenant)
              if (tenant_tasks[tenant.id] || 0) > quota
                delayed_message.update(publish_at: Time.now + 2 * Cenit.scheduler_lookup_interval)
              else
                publish_options = { routing_key: queue.name }
                publish_options[:headers] = { unscheduled: true } if delayed_message.unscheduled
                channel.default_exchange.publish(delayed_message.message, publish_options)
                ActiveTenant.inc_tasks_for(tenant)
                tenant_tasks[tenant.id] ||= 0
                tenant_tasks[tenant.id] += 1
                dispatched_ids << delayed_message.id
              end
            else
              delayed_message.delete
              Setup::SystemReport.create(message: "Delayed message #{delayed_message.message} with no associated tenant was deleted.", type: :warning)
            end
          end

          on_messages_ready = Setup::DelayedMessage
                                .all
                                .limit(2 * maximum_active_tasks)
                                .or(:publish_at.lte => Time.now)
          penalty_factor = 0.75
          penalty_quota = penalty_factor * quota
          penalized_ids = tenant_tasks.keys.select { |id| tenant_tasks[id] > penalty_quota }

          on_messages_ready.and(:tenant_id.nin => penalized_ids).each do |delayed_message|
            delayed_message_digester.call(delayed_message)
          end
          if (dispatched_ids.size + (tenant_tasks.values.reduce(&:+) || 0)) < maximum_active_tasks * penalty_factor
            on_messages_ready.and(:tenant_id.in => penalized_ids)
              .limit(2 * (1 - penalty_factor) * maximum_active_tasks).each do |delayed_message|
              delayed_message_digester.call(delayed_message)
            end
          end
          begin
            Setup::DelayedMessage.where(:id.in => dispatched_ids).destroy_all
          rescue Exception => ex
            Setup::SystemNotification.create_with(message: "Error deleting delayed messages: #{ex.message}")
          end unless dispatched_ids.empty?
          ActiveTenant.clean
        end
      ensure
        channel_mutex.unlock
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
