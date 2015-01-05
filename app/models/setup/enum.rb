module Setup
  module Enum

    def purpose_enum
      [:send, :receive]
    end

    def rule_enum
      ['is now present', 'is no longer present', 'has changed to a value']
    end

    def condition_enum
      ['==', '!=', '>', '<']
    end

  end
end
