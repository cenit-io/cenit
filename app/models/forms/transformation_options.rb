module Forms
  module TransformationOptions
    extend ActiveSupport::Concern

    include Setup::TranslationCommon::ClassMethods

    included do
      field :options, type: String

      validate do
        begin
          self.options = parse_options(options).to_json
        rescue Exception => ex
          errors.add(:options, "syntax error: #{ex.message}")
        end
        errors.blank?
      end
    end
  end
end
