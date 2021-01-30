require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def maximum_active_tasks
        @maximum__active_tasks ||= ENV.fetch('BASE_MULTIPLIER_ACTIVE_TASKS', 50).to_i * (ENV['UNICORN_CENIT_SERVER'].to_b ? Cenit.maximum_unicorn_consumers : 1)
      end

      def tasks_quota(active_tenants = nil)
        active_tenants ||= Cenit::ActiveTenant.active_count
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
                delayed =
                  channel.nil? || channel.closed? ||
                    Cenit.delay_tasks ||
                    scheduler&.activated? ||
                    (publish_at && publish_at > Time.now) ||
                    Cenit::ActiveTenant.tasks_for_current > tasks_quota
                if delayed
                  Setup::DelayedMessage.create(message: message, publish_at: publish_at, scheduler: scheduler)
                else
                  begin
                    channel_mutex.lock
                    Cenit::ActiveTenant.inc_tasks_for_current
                    channel.default_exchange.publish(message, routing_key: queue.name)
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
        message = message.with_indifferent_access
        if (message_token = message.delete(:token))
          if (token = TaskToken.where(token: message_token).first)
            token.destroy
            tenant = token.get_tenant
            if tenant
              Cenit::ActiveTenant.dec_tasks_for(tenant)
              message = JSON.parse(token.data).with_indifferent_access if token.data
              rabbit_consumer = task = nil
              tenant.switch do
                unless (Cenit::MultiTenancy.user_model.current = token.user)
                  if tenant
                    Cenit::MultiTenancy.user_model.current = tenant.owner
                    Setup::SystemReport.create(message: "No token user, using tenant #{tenant.label} owner (task ##{token.task_id})", type: :warning)
                  end
                end
                begin
                  task_class, task, report = detask(message)
                  execution_id = message.delete(:execution_id)
                  if options[:unscheduled.to_s]
                    task&.unschedule
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
                  rabbit_consumer&.update(executor_id: nil, task_id: nil)
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
            else
              Setup::SystemReport.create(message: "Can not determine tenant for message: #{message} (token #{message_token})")
              Setup::SystemReport.create(message: message_token)
            end
          else
            Setup::SystemReport.create(message: "No task token for #{message_token}")
            if Setup::DelayedMessage.purge_message(message_token)
              Setup::SystemReport.create(type: :info, message: "Message purged: #{message_token}")
            else
              Setup::SystemReport.create(type: :warning, message: "Message #{message_token} could not be purged")
            end
          end
        end
      rescue Exception => ex
        Setup::SystemReport.create(message: "Error (#{ex.message}) processing message: #{message}")
      end

      attr_reader :connection, :channel, :queue

      def init
        channel_mutex.lock
        if ENV['SKIP_RABBIT_MQ'].to_b
          puts 'RabbitMQ SKIPPED'
          false
        else
          if @connection.nil? || @channel.nil? || @channel.closed?
            unless @connection
              @connection =
                if (rabbit_url = ENV['RABBITMQ_BIGWIG_TX_URL']).present?
                  Bunny.new(rabbit_url)
                else
                  Bunny.new(
                    automatically_recover: true,
                    user: ENV['RABBIT_MQ_USER'],
                    password: ENV['RABBIT_MQ_PASSWORD']
                  )
                end
              connection.start
            end

            @channel ||= connection.create_channel
            @channel.open if @channel.closed?
            @channel.prefetch(1)

            @queue ||= @channel.queue(Cenit.rabbit_mq_queue)
          end
          true
        end
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
              consumer.cancel if rabbit_consumer&.cancelled?
            ensure
              channel_mutex.unlock
            end
          end
          puts "RABBIT CONSUMER '#{new_consumer.consumer_tag}' STARTED"
          true
        else
          puts 'RabbitMQ consumer not started (RabbitMQ not initialized)'
          false
        end
      rescue Exception => ex
        Setup::SystemNotification.create(message: "Error subscribing RabbitMQ consumer: #{ex.message}")
        false
      end

      def start_scheduler
        if ENV['LOOKUP_SCHEDULER_OFF'].to_b || !init
          puts 'Lookup scheduler NOT STARTED'
          false
        else
          @scheduler_job = Rufus::Scheduler.new.interval(
            "#{Cenit.scheduler_lookup_interval}s",
            &method(:lookup_messages)
          )
          puts 'Lookup scheduler STARTED'
          true
        end
      end

      def lookup_messages(opts = {})
        channel_mutex.lock
        if channel && !channel.closed?
          dispatched_ids = []
          tenant_tasks = {}
          Cenit::ActiveTenant.each do |active_tenant|
            tenant_tasks[active_tenant[:tenant_id]] = active_tenant[:tasks]
          end
          quota = opts[:quota] || tasks_quota(tenant_tasks.size)

          process = proc do |delayed_message|
            tenant_id = delayed_message[:tenant_id]
            if (tenant_tasks[tenant_id] || 0) > quota
              Setup::DelayedMessage.reschedule(delayed_message, Time.now + 2 * Cenit.scheduler_lookup_interval)
            else
              publish_options = { routing_key: queue.name }
              publish_options[:headers] = { unscheduled: true } if delayed_message[:unscheduled]
              channel.default_exchange.publish(delayed_message[:message], publish_options)
              Cenit::ActiveTenant.inc_tasks_for(tenant_id)
              tenant_tasks[tenant_id] ||= 0
              tenant_tasks[tenant_id] += 1
              dispatched_ids << delayed_message[:id]
            end
          end

          penalty_factor = 0.75
          penalty_quota = penalty_factor * quota
          penalized_ids = Set.new(tenant_tasks.keys.select { |id| tenant_tasks[id] > penalty_quota })
          count = tenant_tasks.values.reduce(&:+) || 0
          penalized_messages = []

          Setup::DelayedMessage.for_each_ready(limit: 2 * maximum_active_tasks) do |delayed_message|
            break unless count < maximum_active_tasks
            if penalized_ids.include?(delayed_message[:id])
              penalized_messages << delayed_message
            elsif process.call(delayed_message)
              count += 1
            end
          end

          while count < maximum_active_tasks && penalized_messages.count > 0
            process.call(penalized_messages.shift)
          end

          begin
            Setup::DelayedMessage.where(
              :id.in => dispatched_ids.map { |id| BSON::ObjectId.from_string(id) }
            ).destroy_all
          rescue Exception => ex
            Setup::SystemNotification.create_with(message: "Error deleting delayed messages: #{ex.message}")
          end unless dispatched_ids.empty?
          Cenit::ActiveTenant.clean
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
