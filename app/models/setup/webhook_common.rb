require 'net/ftp'

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
      stack = [using_authorization, self]
      stack.compact!
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
              if connection_role.webhook_ids.include?(self.id)
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
              url: url = connection.conformed_url(template_parameters),
              path: conformed_path(template_parameters)
            )
            template_parameters[:body] = body if body

            uri = URI.parse(url)

            last_response = case uri.scheme
                            when nil, '', 'http', 'https'
                              process_http_connection(connection, template_parameters, verbose_response, last_response, options, &block)
                            else
                              process_connection(template_parameters, verbose_response, last_response, options, &block)
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

    def process_http_connection(connection, template_parameters, verbose_response, last_response, options, &block)
      template_parameters[:method] ||= method
      conformed_url = template_parameters[:url]
      conformed_path = template_parameters[:path]
      body = template_parameters[:body]
      parameters = connection.conformed_parameters(template_parameters)
                     .merge(conformed_parameters(template_parameters))
                     .merge!(options[:parameters] || {})
                     .reject { |_, value| value.blank? }

      template_parameters[:query_parameters] = parameters
      connection.inject_other_parameters(parameters, template_parameters)
      inject_other_parameters(parameters, template_parameters)

      if (auth = using_authorization || connection.using_authorization)
        auth.sign_params(parameters, template_parameters)
      end

      query = parameters.plain_query(skip_encoding: template_parameters['skip_query_encoding'].to_b)
      template_parameters[:query] = query

      headers = {}
      template_parameters[:contentType] = headers['Content-Type'] = options[:contentType] if options.key?(:contentType)
      headers.merge!(connection.conformed_headers(template_parameters))
        .merge!(conformed_headers(template_parameters))
        .merge!(options[:headers] || {})
        .reject! { |_, value| value.nil? }
      halt_anyway = false
      begin
        if body.to_s.empty? && headers['Content-Type'] == 'application/x-www-form-urlencoded'
          body = parameters.www_form_encode
          query = nil
        end
        conformed_path += '?' + query if query.present?
        url = conformed_url.gsub(%r{\/+\Z}, '') + ('/' + conformed_path).gsub(%r{\/+}, '/')
        template_parameters[:uri] ||= url
        if body
          if (attachment_body = body).is_a?(Hash)
            attachment_body = attachment_body.collect do |key, value|
              [
                key, if value.respond_to?(:default_hash)
                       value.default_hash
                     else
                       value
                     end
              ]
            end.to_h
            attachment_body = JSON.pretty_generate(attachment_body)
          end
          attachment = build_attachment(contentType: headers['Content-Type'], body: attachment_body)
          if (request_attachment = options[:request_attachment]).respond_to?(:call)
            attachment = request_attachment.call(attachment)
          end
        else
          attachment = nil
        end
        notification_model.create_with(
          message: JSON.pretty_generate(method: method,
          url: url,
          headers: headers),
          type: :notice,
          attachment: attachment,
          skip_notification_level: options[:skip_notification_level] || options[:notify_request]
        )

        headers.each { |key, value| headers[key] = value.to_s }
        msg = { headers: headers }
        msg[:body] = body if body
        msg[:timeout] = remaining_request_time
        msg[:verify] = false # TODO: Https verify option by Connection
        if (http_proxy = options[:http_proxy_address])
          msg[:http_proxyaddr] = http_proxy
        end
        if (http_proxy_port = options[:http_proxy_port])
          msg[:http_proxyport] = http_proxy_port
        end
        begin
          start_time = Time.current
          http_response = HTTMultiParty.send(method, url, msg)
        rescue Timeout::Error
          http_response = Setup::Webhook::HttpResponse.new(
            true,
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
          )
        rescue Exception => ex
          raise ex
        ensure
          remaining_request_time(start_time - Time.current)
        end
        last_response = http_response.body
        http_response = Setup::Webhook::HttpResponse.new(false, http_response) unless http_response.is_a?(Setup::Webhook::HttpResponse)
        notification_model.create_with(
          message: { response_code: http_response.code }.to_json,
          type: http_response.success? ? :notice : :error,
          attachment: attachment_from(http_response),
          skip_notification_level: options[:skip_notification_level] || options[:notify_response]
        )
        if block
          halt_anyway = true
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
          verbose_response[:http_response] = verbose_response[:response] = http_response
        end
      rescue Exception => ex
        notification_model.create_from(ex)
        raise ex if options[:halt_on_error] || halt_anyway
      end
      last_response
    end

    def process_connection(template_parameters, verbose_response, last_response, options, &block)
      conformed_url = template_parameters[:url]
      conformed_path = template_parameters[:path]
      body = template_parameters[:body]
      halt_anyway = false
      begin
        url = conformed_url.gsub(%r{\/+\Z}, '') + ('/' + conformed_path).gsub(%r{\/+}, '/')
        if body
          fail "Invalid operation '#{method}', non HTTP[S] body submission only supported for PUT operations" unless method == 'put'
          attachment = build_attachment(contentType: options[:contentType], body: body)
          if (request_attachment = options[:request_attachment]).respond_to?(:call)
            attachment = request_attachment.call(attachment)
          end
        else
          fail "Invalid operation '#{method}', non HTTP[S] requests (with no body) only supported for GET operations" unless method == 'get'
          attachment = nil
        end
        notification_model.create_with(
          message: JSON.pretty_generate(
            command: body ? 'put' : 'get',
            url: url
          ),
          type: :notice,
          attachment: attachment,
          skip_notification_level: options[:skip_notification_level] || options[:notify_request]
        )
        #msg[:timeout] = remaining_request_time #TODO handle timeout
        begin
          uri = URI.parse(url)
          process_method = "process_#{uri.scheme}"
          if respond_to?(process_method)
            start_time = Time.current
            result = send(
              process_method,
              host: uri.host,
              path: uri.path,
              body: body,
              template_parameters: template_parameters,
              options: options
            )
            response = Setup::Webhook::Response.new(
              true,
              code: :success,
              body: result,
              headers: {
                filename: uri.path.split('/').last,
                metadata: {
                  uri: uri.to_s,
                  host: uri.host,
                  path: uri.path
                }
              }
            )
          else
            fail "Unsupported file resource scheme: #{uri.scheme}"
          end
        rescue Timeout::Error
          response = Setup::Webhook::Response.new(true, code: :timeout)
        rescue Exception => ex
          raise ex
        ensure
          remaining_request_time(start_time - Time.current)
        end
        last_response = response.body
        notification_model.create_with(
          message: { response_code: response.code }.to_json,
          type: response.success? ? :notice : :error,
          attachment: attachment_from(response),
          skip_notification_level: options[:skip_notification_level] || options[:notify_response]
        )
        if block
          halt_anyway = true
          last_response =
            case block.arity
            when 1
              block.call(response)
            when 2
              block.call(response, template_parameters)
            end
        end
        if verbose_response
          verbose_response[:last_response] = last_response
          verbose_response[:response] = response
        end
      rescue Exception => ex
        notification_model.create_from(ex)
        raise ex if options[:halt_on_error] || halt_anyway
      end
      last_response
    end

    def process_ftp(opts)
      result = nil
      username, password = check(opts[:template_parameters], :username, :password)
      Net::FTP.open(opts[:host], username, password) do |ftp|
        if (body = opts[:body])
          begin
            tempfile = Tempfile.new('ftp')
            tempfile.write(body)
            ftp.putbinaryfile(tempfile, opts[:path])
          ensure
            begin
              tempfile.close
            rescue
            end
          end
        else
          result = ftp.getbinaryfile(opts[:path], nil)
        end
      end
      result
    end

    def process_sftp(opts)
      result = nil
      username, password = check(opts[:template_parameters], :username, :password)
      Net::SFTP.start(opts[:host], username, password: password) do |sftp|
        if (body = opts[:body])
          sftp.file.open(opts[:path], 'w') { |f| f.puts(body) }
        else
          result = sftp.file.open(opts[:path], 'r') { |f| f.gets }
        end
      end
      result
    end

    def process_scp(opts)
      username, password = check(opts[:template_parameters], :username, :password)
      if (body = opts[:body])
        Net::SCP.upload!(opts[:host], username, StringIO.new(body), opts[:path], ssh: { password: password })
      else
        Net::SCP.download!(opts[:host], username, opts[:path], nil, ssh: { password: password })
      end
    end

    def check(template_parameters, *args)
      values = []
      args.collect(&:to_s).each do |key|
        if (value = template_parameters[key].presence)
          values << value
        else
          fail "Template parameter '#{key}' is not present"
        end
      end
      values
    end

    def attachment_from(response)
      if response && (body = response.body)
        build_attachment(base_name: response.object_id.to_s, contentType: response.content_type, body: body)
      else
        nil
      end
    end

    def build_attachment(hash)
      unless hash.key?(:filename)
        filename = hash[:base_name] || DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')
        if (content_type = hash[:contentType]) && (types = MIME::Types[content_type])
          types.each do |type|
            if (ext = type.extensions.first)
              filename = "#{filename}.#{ext}"
              break
            end
          end
        end
        hash[:filename] = filename
      end
      hash[:contentType] ||= 'application/octet-stream'
      hash
    end

    REQUEST_TIME_KEY = '[cenit]remaining_request_time'

    DEFAULT_REQUEST_TIMEOUT = 300

    def remaining_request_time(*args)
      unless (remaining = Thread.current[REQUEST_TIME_KEY])
        Thread.current[REQUEST_TIME_KEY] = remaining = Cenit.request_timeout || DEFAULT_REQUEST_TIMEOUT
      end
      if (delta = args[0])
        Thread.current[REQUEST_TIME_KEY] = [remaining + delta, 1].max
      else
        remaining
      end
    end

    METHODS = %W(GET POST PUT DELETE PATCH COPY OPTIONS LINK UNLINK PURGE LOCK UNLOCK HEAD LINK UNLINK PURGE LOCK UNLOCK PROPFIND)

    SYM_METHODS = METHODS.map(&:downcase).map(&:to_sym)

    module ClassMethods

      def method_enum
        SYM_METHODS
      end
    end


    class HttpResponse

      attr_reader :requester_response

      def initialize(requester_response, response)
        @requester_response = requester_response
        @response = response
      end

      def success?
        (200...299).include?(code)
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

    class Response

      attr_reader :requester_response

      def initialize(requester_response, response)
        @requester_response = requester_response
        @response = response
      end

      def success?
        code == :success
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
        @response[property]
      end
    end
  end
end
