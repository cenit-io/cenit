module Setup
  class Algorithm
    include SharedEditable
    include NamespaceNamed

    build_in_data_type.referenced_by(:namespace, :name)

    field :description, type: String
    embeds_many :parameters, class_name: Setup::AlgorithmParameter.to_s, inverse_of: :algorithm
    field :code, type: String
    embeds_many :call_links, class_name: Setup::CallLink.to_s, inverse_of: :algorithm

    validates_format_of :name, with: /\A[a-z]([a-z]|_|\d)*\Z/

    accepts_nested_attributes_for :parameters, allow_destroy: true
    accepts_nested_attributes_for :call_links, allow_destroy: true

    field :store_output, type: Boolean
    belongs_to :output_datatype, class_name: Setup::DataType.to_s, inverse_of: nil
    field :validate_output, type: Boolean

    before_save :validate_code, :validate_output_processing

    def validate_code
      if code.blank?
        errors.add(:code, "can't be blank")
      else
        Capataz.rewrite(code, halt_on_error: false, logs: logs = {}, locals: parameters.collect { |p| p.name })
        if logs[:errors].present?
          logs[:errors].each { |msg| errors.add(:code, msg) }
          self.call_links = []
        else
          links = []
          (logs[:self_sends] || []).each do |call_name|
            if (call_link = call_links.where(name: call_name).first)
              links << call_link
            else
              links << Setup::CallLink.new(name: call_name)
            end
          end
          self.call_links = links
          do_link
        end
      end
      errors.blank?
    end

    def validate_output_processing
      if store_output and not output_datatype
        rc = Setup::FileDataType.find_or_create_by(namespace: namespace, name: "#{name} output")
        if rc.errors.present?
          errors.add(:output_datatype, rc.errors.full_messages)
        else
          self.output_datatype = rc
        end
      end
      errors.blank?
    end

    def do_link
      call_links.each { |call_link| call_link.do_link }
    end

    attr_accessor :self_linker

    def with_linker(linker)
      self.self_linker = linker
      self
    end

    def do_store_output(output)
      rc = []
      r = nil
      if output_datatype.is_a? Setup::FileDataType
        begin
          case output
            when Hash, Array
              r = output_datatype.create_from!(output.to_json, contentType: 'application/json')
            when String
              ct = 'text/plain'
              begin
                JSON.parse(output)
                ct = 'application/json'
              rescue JSON::ParserError
                unless Nokogiri.XML(output).errors.present?
                  ct = 'application/xml'
                end
              end
              r = output_datatype.create_from!(output, contentType: ct)
            else
              r = output_datatype.create_from!(output.to_s)
          end
        rescue Exception
          r = output_datatype.create_from!(output.to_s)
        end
      else
        begin
          case output
            when Hash, String
              begin
                r = output_datatype.create_from_json!(output)
              rescue Exception => e
                puts e.backtrace
              end
            when Array
              output.each do |item|
                rc += do_store_output(item)
              end
            else
              raise
          end
        rescue Exception
          fail 'Output failed to validate against Output DataType.'
        end
      end
      if r
        if r.errors.present?
          fail 'Output failed to validate against Output DataType.'
        else
          rc << r.id
        end
      end
      rc
    end

    def run(input)
      input = Cenit::Utility.json_value_of(input)
      input = [input] unless input.is_a?(Array)
      args = {}
      parameters.each { |parameter| args[parameter.name] = input.shift }
      do_link
      rc = Cenit::RubyInterpreter.run(code, args, self_linker: self_linker || self)

      if rc.present?
        if store_output
          unless output_datatype
            fail 'Execution failed! Output storage required and no Output DataType defined.'
          end
          begin
            ids = do_store_output rc
            AlgorithmOutput.create(algorithm: self, data_type: output_datatype, output_ids: ids)
          rescue Exception => e
            if validate_output
              fail 'Execution failed!' + e.message
            end
          end
        end
      end

      rc
    end

    def link?(call_symbol)
      link(call_symbol).present?
    end

    def link(call_symbol)
      if (call_link = call_links.where(name: call_symbol).first)
        call_link.do_link
      else
        nil
      end
    end

    def linker_id
      id.to_s
    end

    def for_each_call(visited = Set.new, &block)
      unless visited.include?(self)
        visited << self
        block.call(self) if block
        call_links.each { |call_link| call_link.link.for_each_call(visited, &block) if call_link.link }
      end
    end

    def stored_outputs(options = {})
      AlgorithmOutput.where(algorithm: self).desc(:created_at)
    end
  end
end