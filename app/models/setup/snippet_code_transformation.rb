module Setup
  module SnippetCodeTransformation
    extend ActiveSupport::Concern

    include SnippetCode

    def build_execution_options(options)
      options = super
      options[:code] = code
      options
    end

    def link?(call_symbol)
      link(call_symbol).present?
    end

    def link(call_symbol)
      ivar = "@__link_#{call_symbol}"
      unless instance_variable_defined?(ivar)
        alg = Setup::Algorithm.where(namespace: try(:namespace), name: call_symbol).first ||
          Setup::Algorithm.where(name: call_symbol).first
        instance_variable_set(ivar, alg)
      end
      instance_variable_get(ivar)
    end

    def linker_id
      "t#{id}"
    end
  end
end
