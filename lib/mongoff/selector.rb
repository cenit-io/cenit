module Mongoff
  class Selector < Mongoid::Criteria::Selector

    def evolve_hash(serializer, value)
      value = serializer.evolve_hash(value)
      super
    end

    def multi_selection?(key)
      %w($and $or $nor).include?(key.to_s)
    end
  end
end