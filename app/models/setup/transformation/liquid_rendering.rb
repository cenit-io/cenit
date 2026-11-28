module Setup
  module Transformation
    module LiquidRendering
      def self.export(options, include_id: false)
        source = options.fetch(:source)
        locals = include_id ? source.to_hash(include_id: true) : source.to_hash
        ::Liquid::Template.parse(options[:code]).render(locals)
      end

      def self.convert(options)
        result = ::Liquid::Template.parse(options[:code]).render(options.with_indifferent_access)
        options[:target] = options[:target_data_type].new_from(result)
      end
    end
  end
end
