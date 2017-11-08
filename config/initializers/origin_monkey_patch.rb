
require 'origin/extensions/symbol'

module Origin
  module Extensions
    module Symbol
      module ClassMethods

        def evolve(object)
          __evolve__(object) { |obj| obj.regexp? ? obj : obj.to_sym }
        end
      end
    end
  end
end
