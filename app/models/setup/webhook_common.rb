module Setup
  module WebhookCommon
    extend ActiveSupport::Concern

    include WithTemplateParameters
    include JsonMetadata
    include AuthorizationHandler

    def method_enum
      self.class.method_enum
    end

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
      notification_model = Account.current ? Setup::SystemNotification : Setup::SystemReport
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
              url: conformed_url = connection.conformed_url(template_parameters),
              path: conformed_path = conformed_path(template_parameters),
              method: method
            )
            template_parameters[:body] = body if body

            parameters = connection.conformed_parameters(template_parameters)
                         .merge(conformed_parameters(template_parameters))
                         .merge!(options[:parameters] || {})
                         .reject { |_, value| value.blank? }

            template_parameters[:query_parameters] = parameters
            connection.inject_other_parameters(parameters, template_parameters)
            inject_other_parameters(parameters, template_parameters)

            query = parameters.plain_query
            template_parameters[:query] = query

            headers = {}
            template_parameters[:contentType] = headers['Content-Type'] = options[:contentType] if options.key?(:contentType)
            headers.merge!(connection.conformed_headers(template_parameters))
              .merge!(conformed_headers(template_parameters))
              .merge!(options[:headers] || {})
              .reject! { |_, value| value.nil? }
            begin
              conformed_path += '?' + query if query.present?
              url = conformed_url.gsub(%r{\/+\Z}, '') + ('/' + conformed_path).gsub(%r{\/+}, '/')
              url = url.gsub('/?', '?')

              if body
                attachment = {
                  filename: DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S'),
                  contentType: options[:contentType] || 'application/octet-stream',
                  body: body
                }
                if (request_attachment = options[:request_attachment]).respond_to?(:call)
                  attachment = request_attachment.call(attachment)
                end
              else
                attachment = nil
              end
              notification_model.create_with(message: JSON.pretty_generate(method: method,
                                                                                  url: url,
                                                                                  headers: headers),
                                                    type: :notice,
                                                    attachment: attachment,
                                                    skip_notification_level: options[:skip_notification_level] || options[:notify_request])

              headers.each { |key, value| headers[key] = value.to_s }
              msg = { headers: headers }
              msg[:body] = body if body
              msg[:timeout] = Cenit.request_timeout || 300
              msg[:verify] = false # TODO: Https verify option by Connection
              if (http_proxy = options[:http_proxy_address])
                msg[:http_proxyaddr] = http_proxy
              end
              if (http_proxy_port = options[:http_proxy_port])
                msg[:http_proxyport] = http_proxy_port
              end
              begin
                http_response = HTTMultiParty.send(method, url, msg)
              rescue Timeout::Error
                http_response = Setup::Webhook::Response.new true,
                                                             code: 408,
                                                             content_type: 'application/json',
                                                             body: {
                                                               error: {
                                                                 errors: [
                                                                   {
                                                                     reason: 'timeout',
                                                                     message: "Request timeout (#{msg[:timeout]}s)"
                                                                   }
                                                                 ],
                                                                 code: 408,
                                                                 message: "Request timeout (#{msg[:timeout]}s)"
                                                               }
                                                             }.to_json
              rescue Exception => ex
                raise ex
              end
              last_response = http_response.body

              notification_model.create_with(message: { response_code: http_response.code }.to_json,
                                                    type: (200...299).include?(http_response.code) ? :notice : :error,
                                                    attachment: attachment_from(http_response),
                                                    skip_notification_level: options[:skip_notification_level] || options[:notify_response])

              http_response = Setup::Webhook::Response.new(false, http_response) unless http_response.is_a?(Setup::Webhook::Response)
              if block
                last_response =
                  case block.arity
                  when 1
                    block.call(http_response)
                  when 2
                    block.call(http_response, template_parameters)
                  end
              end
              if verbose_response
                verbose_response[:last_response] = last_response
                verbose_response[:http_response] = http_response
              end
            rescue Exception => ex
              notification_model.create_from(ex)
              raise ex if options[:halt_on_error]
            end
          else
            notification_model.create(message: "Invalid submit data type: #{submitter_body.class}")
          end
        end
      else
        notification_model.create(message: 'No connections available', type: :warning)
      end
      verbose_response || last_response
    end

    def attachment_from(http_response)
      if http_response
        file_extension = ((types = MIME::Types[http_response.content_type]).present? &&
                         (ext = types.first.extensions.first).present? && '.' + ext) || ''
        {
          filename: http_response.object_id.to_s + file_extension,
          contentType: http_response.content_type,
          body: http_response.body
        }
      else
        nil
      end
    end

    module ClassMethods

      def method_enum
        [
          :get,
          :post,
          :put,
          :delete,
          :patch,
          :copy,
          :head,
          :options,
          :link,
          :unlink,
          :purge,
          :lock,
          :unlock,
          :propfind
        ]
      end
    end

    class Response

      attr_reader :requester_response

      def initialize(requester_response, response)
        @requester_response = requester_response
        @response = response
      end

      def requester_response?
        requester_response.to_b
      end

      def code
        get(:code)
      end

      def body
        get(:body)
      end

      def headers
        (get(:headers) || {}).to_hash
      end

      def content_type
        get(:content_type)
      end

      private

      def get(property)
        if requester_response?
          @response[property]
        else
          @response.instance_eval(property.to_s)
        end
      end

    end
  end
end
