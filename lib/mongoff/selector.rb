module Mongoff
  class Selector < Mongoid::Criteria::Selector

    def evolve_hash(serializer, value)
      value = serializer.evolve_hash(value)
      super
    end
  end
end