module Setup
  module Enum

    def purpose_enum
      ['send', 'receive']
    end

    def rule_enum
      ['is now present', 'is no longer present', 'has changed a to value']
    end

    def condition_enum
      ['equal to', 'is not equal to', 'is greater than', 'is less than']
    end

  end
end
