module Forms
  module DataImportCommon
    extend ActiveSupport::Concern

    include Mongoid::Document

    included do
      field :file
      field :decompress_content, type: Boolean
      field :data, type: String

      validate do
        if file.present? && data.present?
          errors.add(:base, 'Both file & data is not allowed')
        end
        if file.blank? && data.blank?
          errors.add(:base, 'File or data is required')
        end
      end
    end
  end
end
