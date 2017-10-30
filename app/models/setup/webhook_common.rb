module Setup
  module WebhookCommon
    extend ActiveSupport::Concern

    include WithTemplateParameters
    include JsonMetadata
    include AuthorizationHandler

    def conformed_path(options = {})
      conform_field_value(:path, options)
    end

    def upon(connections, options = {})
      @connections = connections
      @connection_role_options = options || {}
      self
    end

    def params_stack
      stack = [self]
      stack.unshift(@connections) if @connections.is_a?(Setup::Connection)
      stack
    end

    def with(options)
      case options
      when NilClass
        self
      when Setup::Connection, Setup::ConnectionRole
        upon(options)
      else
        super
      end
    end

    def and(options)
      with(options)
    end

    def connections
      if @connections_cache
        @connections_cache
      else
        connections =
          if @connections
            @connections.is_a?(Setup::Connection) ? [@connections] : (@connections.connections || [])
          else
            connections = []
            Setup::ConnectionRole.all.each do |connection_role|
              if connection_role.webhooks.include?(self)
                connections = (connections + connection_role.connections.to_a).uniq
              end
            end
            connections
          end
        if connections.empty? && (connection = Setup::Connection.where(namespace: namespace).first)
          connections << connection
        end
        @connections_cache = connections unless @connection_role_options &&
                                                @connection_role_options.key?(:cache) &&
                                                !@connection_role_options[:cache]
        connections
      end
    end

    def submit!(*args, &block)
      if (options = args[0]).is_a?(Hash)
        body_argument = options[:body]
      else
        body_argument = options
        options = args[1] || {}
      end
      options[:halt_on_error] = true
      submit(body_argument, options, &block)
    end

    def notification_model
      Account.current ? Setup::SystemNotification : Setup::SystemReport
    end

    def submit(*args, &block)
      if (options = args[0]).is_a?(Hash)
        body_argument = options[:body]
      else
        body_argument = options
        options = args[1] || {}
      end
      last_response = nil
      template_parameters_hash = self.template_parameters_hash.merge!(options[:template_parameters] || {})
      verbose_response = options[:verbose_response] ? {} : nil
      if (connections = self.connections).present?
        verbose_response[:connections_present] = true if verbose_response
        common_submitter_body = (body_caller = body_argument.respond_to?(:call)) ? nil : body_argument
        connections.each do |connection|
          template_parameters = template_parameters_hash.dup
          template_parameters.reverse_merge!(connection.template_parameters_hash)
          submitter_body =
            if body_caller
              body_argument.call(template_parameters)
            else
              common_submitter_body
            end
          submitter_body = '' if body_argument && submitter_body.nil?
          if [Hash, Array, String, NilClass].include?(submitter_body.class)
            case submitter_body
            when Hash
              if options[:contentType] == 'application/json'
                body = submitter_body.to_json
              else
                body = {}
                submitter_body.each do |key, content|
                  body[key] =
                    if content.is_a?(String) || content.respond_to?(:read)
                      content
                    elsif content.is_a?(Hash)
                      UploadIO.new(StringIO.new(content[:data]), content[:contentType], content[:filename])
                    else
                      content.to_s
                    end
                end
              end
            when Array
              body = submitter_body.to_json
            else
              body = submitter_body
            end
            template_parameters.reverse_merge!(
              url: connection.conformed_url(template_parameters),
              path: conformed_path(template_parameters)
            )
            template_parameters[:body] = body if body

            process_connection(connection, template_parameters, verbose_response, last_response, options, &block)
          else
            notification_model.create(message: "Invalid submit data type: #{submitter_body.class}")
          end
        end
      else
        notification_model.create(message: 'No connections available', type: :warning)
      end
      verbose_response || last_response
    end

    def process_connection(connection, template_parameters, verbose_response, last_response, options, &block)
      fail NotImplementedError
    end

    def attachment_from(response)
      if response && (body = response.body)
        file_extension = ((types = MIME::Types[response.content_type]).present? &&
                         (ext = types.first.extensions.first).present? && '.' + ext) || ''
        {
          filename: response.object_id.to_s + file_extension,
          contentType: response.content_type || 'application/octet-stream',
          body: body
        }
      else
        nil
      end
    end
  end
end
