module Setup
  module Transformation
    class DoubleCurlyBracesConversionTransform < Setup::Transformation::AbstractTransform
      include DoubleCurlyBracesTransformer

      class << self

        def run(options = {})
          source_hash = JSON.parse(options[:source].to_json)
          template_hash = JSON.parse(options[:transformation])
          do_template(template_hash, source_hash)
          options[:target].from_json(template_hash)
        end

      end
    end
  end
end
