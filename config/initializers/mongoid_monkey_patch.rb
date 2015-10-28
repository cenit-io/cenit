module Mongoid

  module Scopable

    private

    def apply_default_scoping
      if default_scoping
        default_scoping.call.selector.each do |field, value|
          attributes[field] = value unless field.start_with?('$') || value.respond_to?(:each_pair)
        end
      end
    end
  end
end