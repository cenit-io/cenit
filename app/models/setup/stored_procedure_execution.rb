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

      store_output(message[:input], result) if result.present? && @stored_procedure.store_output

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

    def store_output(input, output)
      fail 'Execution failed! The output data type is not defined.' unless @stored_procedure.output_datatype
      objects = output_objects(output)
      input = JSON.parse(input) if input.is_a?(String)

      begin
        @last_output = StoredProcedureOutput.create(
          stored_procedure: @stored_procedure,
          data_type: @stored_procedure.output_datatype,
          input_params: input,
          output_ids: objects.collect { |o| o.id }
        )
      rescue Exception => e
        fail 'Execution failed!' + e.message if @stored_procedure.validate_output
      end
    end

    def output_objects(output)
      @stored_procedure.output_datatype.is_a?(Setup::FileDataType) ?
        output_file_datatype(output, @stored_procedure.output_datatype) :
        output_db_datatype(output, @stored_procedure.output_datatype)
    end

    def output_db_datatype(output, output_datatype)
      objects = []

      case output
      when Hash, String
        objects << output_datatype.create_from_json!(output)
      when Array
        output.each { |item| objects << output_datatype.create_from_json!(item) }
      else
        raise
      end
    rescue Exception
      fail 'Output failed to validate against Output DataType.'
    end

    def output_file_datatype(output, output_datatype)
      objects = []

      case output
      when Hash, Array
        objects << output_datatype.create_from!(output.to_json, contentType: 'application/json')
      when String
        content_type = 'text/plain'
        begin
          JSON.parse(output)
          content_type = 'application/json'
        rescue JSON::ParserError
          content_type = 'application/xml' unless Nokogiri.XML(output).errors.present?
        end
        objects << output_datatype.create_from!(output, contentType: content_type)
      else
        objects << output_datatype.create_from!(output.to_s)
      end
    rescue Exception
      objects << output_datatype.create_from!(output.to_s)
    end

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
