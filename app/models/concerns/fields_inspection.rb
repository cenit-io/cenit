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
      inspecting_fields = self.inspecting_fields
      changed_attributes.keys.each do |attr|
        attr = attr.to_sym
        unless attr == :_id || inspecting_fields.include?(attr)
          reset_attribute!(attr)
        end
      end
    end
    errors.blank?
  end

  def inspecting_fields
    self.class.inspecting_fields
  end

  module ClassMethods

    def inspect_fields(*args)
      if args.length.positive?
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