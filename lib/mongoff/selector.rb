module Mongoff
  class Selector < Origin::Selector

    def evolve_hash(serializer, value)
      value = serializer.evolve_hash(value)
      super
    end
  end
end