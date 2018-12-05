module Setup
  module RubyCodeTransformation
    extend ActiveSupport::Concern

    include SnippetCodeTransformation

    included do
      before_save :validates_code
    end

    def validates_code
      Capataz.validate(code).each { |error| errors.add(:code, error) }
      errors.blank?
    end

    def additional_local_variables
      {}
    end

    def preprocess_code(code)
      code
    end

    def execute(options)
      options.merge!(additional_local_variables)
      begin
        Cenit::BundlerInterpreter.run_code(preprocess_code(options[:code]), options, self_linker: self)
      rescue Exception => ex
        ex.backtrace.unshift("In template #{namespace}::#{name}")
        fail(ex)
      end
    end

    def code_extension
      '.rb'
    end
  end
end
