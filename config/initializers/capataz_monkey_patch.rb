module Capataz
  class << self
    def allow_invoke_of(methods)
      @config[:allowed_methods] ||= []
      symbol_array_store(:allowed_methods, methods)
    end

    def allowed_method_with_allow_invoke?(options, instance, method)
      @config[:allowed_methods] ||= []
      @config[:allowed_methods].include?(method) || allowed_method_without_allow_invoke?(options, instance, method)
    end

    alias_method_chain :allowed_method?, :allow_invoke
  end
end