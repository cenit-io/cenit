module Setup
  module Transformation
    class DoubleCurlyBracesExportTransform < Setup::Transformation::AbstractTransform
      include DoubleCurlyBracesTransformer

      class << self

        def run(options = {})
          source_hash = JSON.parse(options[:source].to_json)
          template_hash = JSON.parse(options[:transformation])
          do_template(template_hash, source_hash).to_json
        end

      end
    end
  end
end
