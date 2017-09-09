module Setup
  module Transformation
    class PrawnTransform < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          options[:pdf] = PrawnRails::Document.new
          Cenit::BundlerInterpreter.run("#{options[:code]};pdf.render;", options, self_linker: options[:translator])
        end

      end
    end
  end
end
