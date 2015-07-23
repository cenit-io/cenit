module Cenit
  class RubyInterpreter < ActionView::Base

    def run(code, locals = {})
      locals = locals || {}
      render inline: Capataz.rewrite(code, locals: locals.keys), type: :ruby, handlers: :ruby, locals: locals.symbolize_keys
    end

    class << self
      def run(code, locals = {})
        new.run(code, locals)
      end
    end

  end
end