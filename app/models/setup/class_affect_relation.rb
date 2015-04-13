module Setup
  module ClassAffectRelation
    extend ActiveSupport::Concern

    module ClassMethods
      include AffectRelationMethods
    end
  end
end
