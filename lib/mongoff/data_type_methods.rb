module Mongoff
  module DataTypeMethods
    extend ActiveSupport::Concern

    included do
      [:new_from_json, :new_from_xml, :new_from_edi].each do |method|
        class_eval "def #{method}(data, options = {})
          if data_type_methods.any? { |alg| alg.name == '#{method}' }
            method_missing(:#{method}, options)
          else
            super
          end
        end"
      end
    end
  end
end