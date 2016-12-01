require "uri"
require 'net/http'

module Setup
  class StoredProcedureExecution < Setup::Task

    build_in_data_type

    belongs_to :stored_procedure, :class_name => 'Setup::StoredProcedure', inverse_of: nil

    before_save do
      self.stored_procedure = Setup::StoredProcedure.where(id: message[:stored_procedure_id]).first
    end

    def run(message)
      @stored_procedure = Setup::StoredProcedure.find(message[:stored_procedure_id])

      result = run_in_language_bridge(message[:input])

      result = (result.is_a?(Hash) || result.is_a?(Array)) ? JSON.pretty_generate(result) : result.to_s

      attachment = result.present? ? {
        filename: "#{stored_procedure.name.collectionize}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.txt",
        contentType: 'text/plain',
        body: result
      } : nil

      notify(
        message: "'#{stored_procedure.custom_title}' result" + (result.present? ? '' : ' was empty'),
        type: :notice,
        attachment: attachment,
        skip_notification_level: message[:skip_notification_level]
      )
    end

    private

    def run_in_language_bridge(input)
      # Get login account or user.
      login = Account.current || User.current

      uri = URI.parse(bridge_url)
      headers = { 'X-User-Access-Key' => login.key, 'X-User-Access-Token' => login.token }

      # Prepare request.
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.set_form_data({ parameters: input, code: @stored_procedure.code })

      # Prepare http connection.
      http = Net::HTTP.new(uri.host, uri.port, ENV['PROXY_HOST'], ENV['PROXY_PORT'], ENV['PROXY_USER'], ENV['PROXY_PASS'])
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      # http.set_debug_output($stdout)

      # Send request and get response.
      response = http.request(request)

      response.body
    end

    def bridge_url
      lang = @stored_procedure.language.to_s
      ENV["BRIDGES_#{lang.upcase}"] || "https://cenit-rarg-#{lang.downcase}.herokuapp.com"
    end

  end

end
