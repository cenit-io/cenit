require 'shellwords'
require 'socket'
require 'uri'
require 'open3'

namespace :api do
  namespace :v3 do
    local_rabbit_url = 'amqp://cenit_rabbit:cenit_rabbit@127.0.0.1:5672/cenit_rabbit_vhost'.freeze

    with_local_rabbit_defaults = lambda do |&block|
      previous_rabbit = ENV['RABBITMQ_BIGWIG_TX_URL']
      ENV['RABBITMQ_BIGWIG_TX_URL'] = local_rabbit_url if previous_rabbit.nil? || previous_rabbit.empty?
      block.call
    ensure
      previous_rabbit.nil? ? ENV.delete('RABBITMQ_BIGWIG_TX_URL') : ENV['RABBITMQ_BIGWIG_TX_URL'] = previous_rabbit
    end

    tcp_reachable = lambda do |host, port, timeout: 2|
      Socket.tcp(host, port, connect_timeout: timeout.to_i) { |socket| socket.close }
      true
    rescue StandardError
      false
    end

    command_output = lambda do |*cmd|
      output, status = Open3.capture2e(*cmd)
      status.success? ? output.to_s.strip : nil
    rescue StandardError
      nil
    end

    docker_compose_endpoint = lambda do |service, container_port|
      output = command_output.call('docker', 'compose', 'port', service, container_port.to_s)
      next nil if output.to_s.empty?
      host_port = output.lines.first.to_s.strip
      host_port = host_port.sub(/^\[::\]:/, '127.0.0.1:')
      host_port = host_port.sub(/^0\.0\.0\.0:/, '127.0.0.1:')
      return nil unless host_port.include?(':')

      host = host_port.split(':')[0..-2].join(':')
      port = host_port.split(':').last.to_i
      [host, port]
    end

    docker_container_endpoint = lambda do |service, container_port|
      container_id = command_output.call('docker', 'compose', 'ps', '-q', service)
      next nil if container_id.to_s.empty?
      ip = command_output.call(
        'docker',
        'inspect',
        '-f',
        '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}',
        container_id
      )
      next nil if ip.to_s.empty?
      [ip, container_port.to_i]
    end

    resolve_reachable_endpoint = lambda do |candidates, docker_service:, container_port:|
      checked = []
      candidates.each do |host, port|
        next if host.to_s.empty? || port.to_i <= 0
        checked << "#{host}:#{port}"
        return [host, port, checked] if tcp_reachable.call(host, port)
      end

      compose_endpoint = docker_compose_endpoint.call(docker_service, container_port)
      if compose_endpoint
        host, port = compose_endpoint
        checked << "#{host}:#{port} (docker-compose port)"
        return [host, port, checked] if tcp_reachable.call(host, port)
      end

      container_endpoint = docker_container_endpoint.call(docker_service, container_port)
      if container_endpoint
        host, port = container_endpoint
        checked << "#{host}:#{port} (container ip)"
        return [host, port, checked] if tcp_reachable.call(host, port)
      end

      [nil, nil, checked]
    end

    parse_host_port_from_uri = lambda do |uri_text, default_port:|
      uri = URI.parse(uri_text)
      host = uri.host
      port = uri.port || default_port
      [host, port]
    rescue StandardError
      [nil, nil]
    end

    assert_dependencies_ready = lambda do
      rabbit_url = ENV['RABBITMQ_BIGWIG_TX_URL'].to_s
      rabbit_host, rabbit_port = parse_host_port_from_uri.call(rabbit_url, default_port: 5672)
      rabbit_host ||= '127.0.0.1'
      rabbit_port ||= 5672

      mongo_uri = ENV['MONGODB_URI'].to_s
      mongo_host, mongo_port = parse_host_port_from_uri.call(mongo_uri, default_port: 27017)
      env_mongo_host = ENV['MONGODB_HOST'].to_s
      env_mongo_host = ENV['MONGO_HOST'].to_s if env_mongo_host.empty?
      mongo_host ||= (env_mongo_host.empty? ? '127.0.0.1' : env_mongo_host)
      env_mongo_port = ENV['MONGODB_PORT'].to_s
      env_mongo_port = ENV['MONGO_PORT'].to_s if env_mongo_port.empty?
      mongo_port ||= (env_mongo_port.empty? ? 27017 : env_mongo_port.to_i)

      mongo_reachable_host, mongo_reachable_port, mongo_checked = resolve_reachable_endpoint.call(
        [[mongo_host, mongo_port]],
        docker_service: 'mongo_server',
        container_port: 27017
      )
      rabbit_reachable_host, rabbit_reachable_port, rabbit_checked = resolve_reachable_endpoint.call(
        [[rabbit_host, rabbit_port]],
        docker_service: 'rabbitmq',
        container_port: 5672
      )

      missing = []
      unless mongo_reachable_host
        missing << "MongoDB unreachable (checked: #{mongo_checked.join(', ')})"
      end
      unless rabbit_reachable_host
        missing << "RabbitMQ unreachable (checked: #{rabbit_checked.join(', ')})"
      end
      next if missing.empty?

      abort("API v3 preflight failed: #{missing.join(', ')} unreachable. Start required services and retry.")
    end

    run_targeted_spec = lambda do |file:, tag:|
      file_arg = Shellwords.escape(file)
      tag_arg = Shellwords.escape(tag)
      # Force a single-file run to avoid loading unrelated spec files.
      sh "bundle exec rspec #{file_arg} --pattern #{file_arg} --tag #{tag_arg}"
    end

    desc 'Run API v3 integration journey (strict by default)'
    task :journey do
      previous = ENV['API_JOURNEY_STRICT']
      ENV['API_JOURNEY_STRICT'] = '1' if previous.nil?
      with_local_rabbit_defaults.call do
        assert_dependencies_ready.call
        run_targeted_spec.call(
          file: 'spec/requests/app/controllers/api/v3/integration_journey_spec.rb',
          tag: 'api_journey'
        )
      end
    ensure
      previous.nil? ? ENV.delete('API_JOURNEY_STRICT') : ENV['API_JOURNEY_STRICT'] = previous
    end

    desc 'Run API v3 login precheck (strict auth context)'
    task :login do
      with_local_rabbit_defaults.call do
        assert_dependencies_ready.call
        run_targeted_spec.call(
          file: 'spec/requests/app/controllers/api/v3/api_login_spec.rb',
          tag: 'api_login'
        )
      end
    end

    desc 'Run API v3 contact-flow precheck'
    task :contact_flow do
      with_local_rabbit_defaults.call do
        assert_dependencies_ready.call
        run_targeted_spec.call(
          file: 'spec/requests/app/controllers/api/v3/api_contact_flow_spec.rb',
          tag: 'api_contact_flow'
        )
      end
    end

    namespace :journey do
      desc 'Run API v3 integration journey in strict mode'
      task :strict do
        previous = ENV['API_JOURNEY_STRICT']
        ENV['API_JOURNEY_STRICT'] = '1'
        with_local_rabbit_defaults.call do
          assert_dependencies_ready.call
          run_targeted_spec.call(
            file: 'spec/requests/app/controllers/api/v3/integration_journey_spec.rb',
            tag: 'api_journey'
          )
        end
      ensure
        previous.nil? ? ENV.delete('API_JOURNEY_STRICT') : ENV['API_JOURNEY_STRICT'] = previous
      end
    end
  end
end
