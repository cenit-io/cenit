# frozen_string_literal: true

require 'json'

class CenitFlowExecutionSmokeRunner
  def initialize
    @started_at = Time.now.utc
    @stamp = ENV.fetch('CENIT_E2E_TIMESTAMP', @started_at.strftime('%Y%m%d%H%M%S'))
    @user_email = ENV.fetch('CENIT_E2E_EMAIL', 'support@cenit.io')
    @namespace = ENV.fetch('CENIT_E2E_FLOW_NAMESPACE', 'E2E_FLOW_EXECUTION')
    @data_type_name = ENV.fetch('CENIT_E2E_FLOW_DATATYPE_NAME', 'Contact')
    @translator_name = ENV.fetch('CENIT_E2E_FLOW_TRANSLATOR_NAME', 'ContactNameUpdater')
    @flow_name = ENV.fetch('CENIT_E2E_FLOW_NAME', 'ContactNameFlow')
    @record_name = ENV.fetch('CENIT_E2E_FLOW_RECORD_NAME', 'John Flow E2E')
    @name_suffix = ENV.fetch('CENIT_E2E_FLOW_SUFFIX', "FLOW-#{@stamp}")
    @timeout_seconds = ENV.fetch('CENIT_E2E_FLOW_TIMEOUT', '120').to_i
    @poll_seconds = ENV.fetch('CENIT_E2E_FLOW_POLL_SECONDS', '1').to_f
    @cleanup_enabled = ENV.fetch('CENIT_E2E_CLEANUP', '1') != '0'
    @warnings = []

    @summary = {
      status: 'running',
      started_at: @started_at.iso8601,
      user_email: @user_email,
      namespace: @namespace,
      data_type_name: @data_type_name,
      translator_name: @translator_name,
      flow_name: @flow_name,
      record_name: @record_name,
      name_suffix: @name_suffix,
      cleanup_enabled: @cleanup_enabled
    }
  end

  def run!
    user = User.where(email: @user_email).first
    raise "User not found for email #{@user_email}" unless user

    tenant = user.account || user.accounts.first || user.member_accounts.first
    raise "Could not determine tenant for #{@user_email}" unless tenant

    @summary[:tenant_id] = tenant.id.to_s
    @summary[:tenant_name] = tenant.name

    previous_user = User.current
    begin
      User.current = user
      tenant.switch do
        validate_rabbit_consumer!
        pre_clean!
        create_resources!
        execute_flow!
        wait_for_completion!
        verify_record!
      ensure
        cleanup_resources! if @cleanup_enabled
      end
    ensure
      User.current = previous_user
    end

    @summary[:warnings] = @warnings unless @warnings.empty?
    @summary[:status] = 'ok'
    @summary[:finished_at] = Time.now.utc.iso8601
    puts JSON.pretty_generate(@summary)
  rescue StandardError => e
    @summary[:status] = 'failed'
    @summary[:error] = e.message
    @summary[:backtrace] = Array(e.backtrace).first(15)
    @summary[:warnings] = @warnings unless @warnings.empty?
    @summary[:finished_at] = Time.now.utc.iso8601
    puts JSON.pretty_generate(@summary)
    raise
  end

  private

  def validate_rabbit_consumer!
    consumer_count = RabbitConsumer.where(alive: true).count
    @summary[:rabbit_consumers_alive] = consumer_count
    raise 'No alive RabbitMQ consumer found in tenant context' if consumer_count.zero?
  end

  def pre_clean!
    destroy_scoped_records!(Setup::Flow, @flow_name)
    destroy_scoped_records!(Setup::RubyUpdater, @translator_name)
    destroy_scoped_records!(Setup::JsonDataType, @data_type_name)
  end

  def create_resources!
    @data_type = Setup::JsonDataType.new(namespace: @namespace, name: @data_type_name)
    @data_type.schema = {
      'type' => 'object',
      'properties' => {
        'name' => { 'type' => 'string' }
      },
      'required' => ['name']
    }
    save_or_fail!(@data_type, "data type #{@namespace} | #{@data_type_name}")

    @record = @data_type.create_from_json!({ 'name' => @record_name })

    updater_code = <<~RUBY
      target.name = [target.name, #{@name_suffix.inspect}].join(" | ")
      target
    RUBY

    @translator = Setup::RubyUpdater.new(
      namespace: @namespace,
      name: @translator_name,
      target_data_type: @data_type,
      code: updater_code
    )
    save_or_fail!(@translator, "translator #{@namespace} | #{@translator_name}")

    @flow = Setup::Flow.new(
      namespace: @namespace,
      name: @flow_name,
      translator: @translator,
      active: true
    )
    save_or_fail!(@flow, "flow #{@namespace} | #{@flow_name}")

    @summary[:data_type_id] = @data_type.id.to_s
    @summary[:record_id] = @record.id.to_s
    @summary[:translator_id] = @translator.id.to_s
    @summary[:flow_id] = @flow.id.to_s
  end

  def execute_flow!
    rabbit_initialized = Cenit::Rabbit.init
    @summary[:rabbit_initialized] = rabbit_initialized
    raise 'RabbitMQ channel could not be initialized from runner context' unless rabbit_initialized

    # Force tenant task counters to a neutral value so the message is published immediately.
    Cenit::ActiveTenant.set_tasks(0, Account.current)
    Cenit::ActiveTenant.clean

    @execution = @flow.process(
      source_id: @record.id.to_s,
      asynchronous: true,
      task_description: "E2E flow execution smoke #{@stamp}"
    )

    raise 'Flow.process did not return an execution object' unless @execution&.id

    @summary[:execution_id] = @execution.id.to_s
    @summary[:execution_status_initial] = @execution.status.to_s
    @task_token = TaskToken.where(task_id: @execution.task_id).first if @execution.task_id
    @summary[:task_token_found] = !@task_token.nil?
    delayed_scope = delayed_messages_for_current_task
    @summary[:delayed_messages_after_enqueue] = delayed_scope.count
    dispatch_delayed_messages!(delayed_scope) if delayed_scope.any?
  end

  def wait_for_completion!
    deadline = Time.now + @timeout_seconds
    @task = nil

    loop do
      @execution = Setup::Execution.where(id: @execution.id).first
      @task =
        if @execution&.task_id
          Setup::FlowExecution.where(id: @execution.task_id).first
        else
          Setup::FlowExecution.where(flow: @flow).first
        end

      if @task
        @task.reload
        @summary[:task_id] = @task.id.to_s
        @summary[:task_status] = @task.status.to_s
        if Setup::Task::FINISHED_STATUS.include?(@task.status)
          break
        end
      end

      raise "Timed out waiting for flow execution after #{@timeout_seconds}s" if Time.now >= deadline

      sleep(@poll_seconds)
    end

    return if @task.status == :completed

    recent_messages = @task.notifications.desc(:created_at).limit(5).collect(&:message)
    raise "Flow execution finished with status #{@task.status}: #{recent_messages.join(' | ')}"
  end

  def verify_record!
    updated_record = @data_type.where(id: @record.id).first
    raise "Record with ID #{@record.id} was not found after flow execution" unless updated_record

    expected_name = [@record_name, @name_suffix].join(' | ')
    actual_name = record_name_of(updated_record)
    raise "Record name mismatch. Expected '#{expected_name}', got '#{actual_name}'" unless actual_name == expected_name

    @summary[:record_name_after_flow] = actual_name
  end

  def cleanup_resources!
    if @record && @data_type
      record = @data_type.where(id: @record.id).first
      begin
        record&.destroy
      rescue StandardError => e
        @warnings << "Record cleanup warning (#{@record.id}): #{e.message}"
      end
    end

    destroy_scoped_records!(Setup::Flow, @flow_name)
    destroy_scoped_records!(Setup::RubyUpdater, @translator_name)
    destroy_scoped_records!(Setup::JsonDataType, @data_type_name)

    leftovers = []
    leftovers << 'flow' if Setup::Flow.where(namespace: @namespace, name: @flow_name).exists?
    leftovers << 'translator' if Setup::RubyUpdater.where(namespace: @namespace, name: @translator_name).exists?
    leftovers << 'data_type' if Setup::JsonDataType.where(namespace: @namespace, name: @data_type_name).exists?
    raise "Cleanup failed, leftover resources: #{leftovers.join(', ')}" unless leftovers.empty?
  end

  def dispatch_delayed_messages!(delayed_scope)
    delayed_messages = delayed_scope.to_a
    @summary[:delayed_messages_dispatched] = delayed_messages.count
    @summary[:delayed_message_ids] = delayed_messages.collect { |delayed| delayed.id.to_s }
    delayed_messages.each do |delayed|
      Cenit::Rabbit.channel.default_exchange.publish(delayed.message, routing_key: Cenit::Rabbit.queue.name)
      Cenit::ActiveTenant.inc_tasks_for_current
      delayed.destroy
    end
  end

  def delayed_messages_for_current_task
    scope = Setup::DelayedMessage.where(tenant: Account.current)
    if @task_token&.token
      scope.where(message: @task_token.token)
    else
      scope.where(message: '__no_task_token__')
    end
  end

  def destroy_scoped_records!(klass, name)
    scope = klass.where(namespace: @namespace, name: name).to_a
    scope.each do |record|
      begin
        record.destroy
      rescue StandardError => e
        @warnings << "#{klass} destroy warning for #{record.id}: #{e.message}"
      ensure
        if klass.where(id: record.id).exists?
          klass.where(id: record.id).delete_all
          @warnings << "#{klass} force-deleted #{record.id}"
        end
      end
    end
  end

  def save_or_fail!(record, label)
    return if record.save

    message = record.errors.full_messages.to_sentence
    raise "Could not save #{label}: #{message}"
  end

  def record_name_of(record)
    if record.respond_to?(:[])
      record['name'] || record[:name]
    elsif record.respond_to?(:name)
      record.name
    end
  end
end

CenitFlowExecutionSmokeRunner.new.run!
