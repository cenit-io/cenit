module Setup
  class FileResource < Webhook
    include NamespaceNamed
    include CustomTitle
    include RailsAdmin::Models::Setup::FileResourceAdmin

    build_in_data_type.referenced_by(:namespace, :name)

    field :path, type: String
    field :description, type: String

    parameters :template_parameters

    validates_presence_of :path

    def process_connection(connection, template_parameters, verbose_response, last_response, options, &block)
      conformed_url = template_parameters[:url]
      conformed_path = template_parameters[:path]
      body = template_parameters[:body]
      halt_anyway = false
      begin
        url = conformed_url.gsub(%r{\/+\Z}, '') + ('/' + conformed_path).gsub(%r{\/+}, '/')
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
        notification_model.create_with(
          message: JSON.pretty_generate(
            command: body ? 'put' : 'get',
            url: url
          ),
          type: :notice,
          attachment: attachment,
          skip_notification_level: options[:skip_notification_level] || options[:notify_request]
        )
        # msg[:timeout] = Cenit.request_timeout || 300
        begin
          uri = URI.parse(url)
          process_method = "process_#{uri.scheme}"
          if respond_to?(process_method)
            result = send(
              process_method,
              host: uri.host,
              path: uri.path,
              body: body,
              template_parameters: template_parameters,
              options: options
            )
            response = Setup::FileResource::Response.new(
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
          response = Setup::FileResource::Response.new(true, code: :timeout)
        rescue Exception => ex
          raise ex
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
