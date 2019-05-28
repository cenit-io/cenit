require 'rkelly'

module Setup
  class Algorithm
    include SnippetCode
    include NamespaceNamed
    include Taggable
    # = Algorithm
    #
    # Is a core concept in Cenit, define function that is possible execute.

    legacy_code_attribute :code

    trace_include :code

    build_in_data_type.referenced_by(:namespace, :name)

    field :description, type: String
    embeds_many :parameters, class_name: Setup::AlgorithmParameter.to_s, inverse_of: :algorithm
    embeds_many :call_links, class_name: Setup::CallLink.to_s, inverse_of: :algorithm

    validates_format_of :name, with: /\A[a-z]([a-z]|_|\d)*\Z/

    accepts_nested_attributes_for :parameters, allow_destroy: true
    accepts_nested_attributes_for :call_links, allow_destroy: true

    field :store_output, type: Boolean
    belongs_to :output_datatype, class_name: Setup::DataType.to_s, inverse_of: nil
    field :validate_output, type: Boolean

    before_save :validate_parameters, :validate_code, :validate_output_processing

    attr_reader :last_output

    field :language, type: Symbol, default: -> { new_record? ? :auto : :ruby }

    validates_inclusion_of :language, in: ->(alg) { alg.class.language_enum.values }

    def code_extension
      case language
      when :python
        '.py'
      when :javascript
        '.js'
      when :php
        '.php'
      else
        '.rb'
      end
    end

    def validate_parameters
      not_required = false
      parameters.each do |p|
        next unless not_required ||= !p.required
        p.errors.add(:required, 'marked as "Required" must come before non marked') if p.required
      end
      errors.add(:parameters, 'contains invalid sequence of required parameters') if (last = parameters.last) && last.errors.present?
      errors.blank?
    end

    def validate_code
      if code.blank?
        errors.add(:code, "can't be blank")
      else
        logs = parse_code
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
      if store_output && !output_datatype
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
      call_links.each(&:do_link)
    end

    attr_accessor :self_linker

    def with_linker(linker)
      self.self_linker = linker
      self
    end

    def do_store_output(output)
      rc = []
      r = nil

      while output.capataz_proxy?
        output = output.capataz_slave
      end

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
            fail
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

    def run_asynchronous(*args, &block)
      options =
        if args.last.is_a?(Hash)
          args.pop
        else
          {}
        end
      input =
        case args.length
        when 0
          options[:input] || []
        when 1
          args[0]
        else
          args
        end
      input = Cenit::Utility.json_value_of(input)
      input = [input] unless input.is_a?(Array)
      Setup::AlgorithmExecution.process(options.merge(algorithm_id: id.to_s, input: input), &block)
    end

    def run(input = [], task = nil)
      input = Cenit::Utility.json_value_of(input)
      input = [input] unless input.is_a?(Array)
      input = input.dup
      if (index = task_parameter_index) && index <= input.length && input[index].nil?
        if index < input.length
          input[index] = task || Setup::Task.current
        else
          input << task || Setup::Task.current
        end
      end

      begin
        rc = Cenit::BundlerInterpreter.run(self, *input)
      rescue Exception => ex
        ex.backtrace.unshift("In algorithm #{namespace}::#{name}")
        raise ex
      end

      if rc
        if store_output
          unless output_datatype
            fail 'Execution failed! Output storage required and no Output DataType defined.'
          end
          begin
            ids = do_store_output(rc)

            args = {}
            parameters.each { |parameter| args[parameter.name] = input.shift }
            @last_output = AlgorithmOutput.create(
              algorithm: self,
              data_type: output_datatype,
              input_params: args,
              output_ids: ids)
          rescue Exception => e
            fail "Failing storing output: #{e.message}" if validate_output
          end
        end
      end

      rc
    end

    def task_parameter_index
      # TODO Force task parameter type when parameters types include cenit data types
      parameters.each_with_index do |p, i|
        return i if p.name == 'task'
      end
      nil
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

    def stored_outputs(_options = {})
      AlgorithmOutput.where(algorithm: self).desc(:created_at)
    end

    def configuration_schema
      schema =
        {
          type: 'object',
          properties: properties = {},
          required: parameters.select(&:required).collect(&:name)
        }
      parameters.each { |p| properties[p.name] = p.schema }
      schema.stringify_keys
    end

    def configuration_model
      @mongoff_model ||= Mongoff::Model.for(
        data_type: self.class.data_type,
        schema: configuration_schema,
        name: self.class.configuration_model_name,
        cache: false)
    end

    def language_name
      self.class.language_enum.keys.detect { |key| self.class.language_enum[key] == language }
    end

    class << self
      def language_enum
        {
          'Auto detect': :auto,
          # 'Python': :python,
          # 'PHP': :php,
          'JavaScript': :javascript,
          'Ruby': :ruby
        }
      end

      def configuration_model_name
        "#{Setup::Algorithm}::Config"
      end
    end

    def parse_code
      if language == :auto
        logs = {}
        lang = self.class.language_enum.values.detect do |language|
          next if language == :auto
          logs.clear
          parse_method = "parse_#{language}_code"
          logs.merge!(send(parse_method))
          logs[:errors].blank?
        end
        if lang
          self.language = lang
        else
          logs.clear
          logs[:errors] = ["can't be auto-detected with syntax errors or typed language is not supported"]
        end
        logs
      else
        parse_method = "parse_#{language}_code"
        send(parse_method)
      end
    end

    protected

    def parse_ruby_code
      logs = { errors: errors = [] }
      unless Capataz.rewrite(code, halt_on_error: false, logs: logs, locals: parameters.collect(&:name))
        errors << 'with no valid Ruby syntax'
      end
      logs
    end

    def parse_javascript_code
      logs = { errors: errors = [] }
      ast =
        begin
          RKelly.parse(code)
        rescue Exception
          nil
        end
      if ast
        logs[:self_sends] = call_names = Set.new
        ast.each do |node|
          if node.is_a?(RKelly::Nodes::FunctionCallNode) && (node = node.value).is_a?(RKelly::Nodes::ResolveNode)
            call_names << node.value
          end
        end
      else
        errors << 'with no valid JavaScript syntax'
      end
      logs
    end

    def parse_php_code
      {
        errors: ['PHP parsing not yet supported']
      }
    end

    def parse_python_code
      {
        errors: ['Python parsing not yet supported']
      }
    end

  end
end

class Array
  def range=(arg)
    @range = arg
  end
end
