module Setup
  module HttpHook
    extend ActiveSupport::Concern

    include WebhookCommon

    def method_enum
      self.class.method_enum
    end

    def process_connection(connection, template_parameters, verbose_response, last_response, options, &block)
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

      query = parameters.plain_query
      template_parameters[:query] = query

      headers = {}
      template_parameters[:contentType] = headers['Content-Type'] = options[:contentType] if options.key?(:contentType)
      headers.merge!(connection.conformed_headers(template_parameters))
        .merge!(conformed_headers(template_parameters))
        .merge!(options[:headers] || {})
        .reject! { |_, value| value.nil? }
      halt_anyway = false
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
          http_response = Setup::HttpHook::Response.new true,
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
        http_response = Setup::HttpHook::Response.new(false, http_response) unless http_response.is_a?(Setup::HttpHook::Response)
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
  end
end
