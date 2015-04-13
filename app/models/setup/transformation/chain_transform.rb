module Setup
  module Transformation
    class ChainTransform < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          if (save_result = options[:save_result]).nil?
            save_result = true
          end
          result = options[:source_exporter].run(object: options[:source],
                                                 save_result: save_result && !options[:discard_chained_records],
                                                 discard_events: options[:discard_events])
          options[:target_importer].run(object: result,
                                        save_result: save_result,
                                        discard_events: options[:discard_events])
        end

      end
    end
  end
end
