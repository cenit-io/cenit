module FieldsInspection
  extend ActiveSupport::Concern

  included do
    before_save :inspect_updated_fields
  end

  def save(options = {})
    @inspect_fields = options.delete(:inspect_fields)
    super
  end

  def inspect_updated_fields
    if @inspect_fields
      inspecting_fields = self.class.inspecting_fields
      changed_attributes.keys.each do |attr|
        reset_attribute!(attr) unless inspecting_fields.include?(attr.to_sym)
      end
    end
    errors.blank?
  end

  module ClassMethods

    def inspect_fields(*args)
      if args.length > 0
        @inspecting_fields = args.collect(&:to_s).collect(&:to_sym)
      end
      @inspecting_fields || []
    end

    def inspecting_fields
      if superclass < FieldsInspection
        superclass.inspecting_fields
      else
        []
      end + inspect_fields
    end
  end
end