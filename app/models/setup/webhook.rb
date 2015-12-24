module Setup
  class Webhook
    include CenitScoped
    include NamespaceNamed
    include ParametersCommon
    include JsonMetadata
    include AuthorizationHandler

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:connection_roles)

    embeds_many :parameters, class_name: Setup::Parameter.to_s, inverse_of: :webhook
    embeds_many :headers, class_name: Setup::Parameter.to_s, inverse_of: :webhook

    embeds_many :template_parameters, class_name: Setup::Parameter.to_s, inverse_of: :webhook

    field :path, type: String
    field :method, type: String, default: :post
    field :description, type: String

    def method_enum
      [:get, :post, :put, :delete, :patch, :copy, :head, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]
    end

    validates_presence_of :path

    accepts_nested_attributes_for :parameters, :headers, :template_parameters, allow_destroy: true

    def conformed_path(options = {})
      conform_field_value(:path, options)
    end

    def upon(connections, options = {})
      @connections = connections
      @connection_role_options = options || {}
      self
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
        @connections_cache = connections unless @connection_role_options &&
          @connection_role_options.has_key?(:cache) &&
          !@connection_role_options[:cache]
        connections
      end
    end

    def submit(*args, &block)
      if (options = args[0]).is_a?(Hash)
        body_argument = options[:body]
      else
        body_argument = options
        options = args[1] || {}
      end
      last_response = nil
      template_parameters_hash = self.template_parameters_hash
      verbose_response = options[:verbose_response] ? {} : nil
      if (connections = self.connections).present?
        verbose_response[:connections_present] = true if verbose_response
        common_submitter_body = (body_caller = body_argument.respond_to?(:call)) ? nil : body_argument
        common_template_parameters = nil
        connections.each do |connection|
          template_parameters = template_parameters_hash.dup
          template_parameters.reverse_merge!(connection.template_parameters_hash) if connection.template_parameters.present?
          submitter_body =
            if body_caller
              body_argument.call(template_parameters)
            else
              common_submitter_body
            end
          submitter_body = '' if body_argument && submitter_body.nil?
          if [NilClass, Hash, String].include?(submitter_body.class)
            url_parameter = connection.conformed_parameters(template_parameters).merge(conformed_parameters(template_parameters)).reject { |_, value| value.blank? }.to_param
            if url_parameter.present?
              url_parameter = '?' + url_parameter
            end
            if submitter_body.is_a?(Hash)
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
            else
              body = submitter_body
            end
            template_parameters.reverse_merge!(
              url: conformed_url = connection.conformed_url(template_parameters),
              path: conformed_path = conformed_path(template_parameters) + url_parameter,
              method: method
            )
            template_parameters[:body] = body if body
            headers = {}
            headers['Content-Type'] = options[:contentType] if options.has_key?(:contentType)
            headers.merge!(connection.conformed_headers(template_parameters)).merge!(conformed_headers(template_parameters))
            begin
              url = conformed_url + ('/' + conformed_path).gsub(/\/+/, '/')
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
              Setup::Notification.create_with(message: JSON.pretty_generate(method: method,
                                                                            url: url,
                                                                            headers: headers),
                                              type: :notice,
                                              attachment: attachment,
                                              skip_notification_level: options[:skip_notification_level] || options[:notify_request])

              msg = { headers: headers }
              msg[:body] = body if body
              http_response = HTTMultiParty.send(method, url, msg)
              last_response = http_response.body

              Setup::Notification.create_with(message: { response_code: http_response.code }.to_json,
                                              type: (200...299).include?(http_response.code) ? :notice : :error,
                                              attachment: attachment_from(http_response),
                                              skip_notification_level: options[:skip_notification_level] || options[:notify_response])

              if block
                http_response = ResponseProxy.new(http_response)
                last_response =
                  case block.arity
                  when 1
                    block.call(http_response)
                  when 2
                    block.call(http_response, template_parameters)
                  end
              end
              verbose_response[:last_response] = last_response if verbose_response
            rescue Exception => ex
              Setup::Notification.create(message: ex.message)
            end
          else
            Setup::Notification.create(message: "Invalid submit data type: #{submitter_body.class}")
          end
        end
      else
        Setup::Notification.create(message: 'No connections available', type: :warning)
      end
      verbose_response || last_response
    end

    def attachment_from(http_response)
      if http_response
        file_extension = ((types =MIME::Types[http_response.content_type]).present? &&
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

    class ResponseProxy

      def initialize(response)
        @response = response
      end

      def code
        @response.code
      end

      def body
        @response.body
      end

      def headers
        @response.headers.to_hash
      end
    end
  end
end
