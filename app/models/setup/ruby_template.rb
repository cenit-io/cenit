module Setup
  class RubyTemplate < Template
    include BulkableTransformation
    include SnippetCodeTemplate
    include RailsAdmin::Models::Setup::RubyTemplateAdmin

    before_save :validates_code

    def validates_code
      Capataz.validate(code).each { |error| errors.add(:code, error) }
      errors.blank?
    end

    def execute(options)
      Cenit::BundlerInterpreter.run_code(options[:code], options, self_linker: self)
    end

    def code_extension
      '.rb'
    end

    def ready_to_save?
      true
    end

    def can_be_restarted?
      false
    end
  end
end
