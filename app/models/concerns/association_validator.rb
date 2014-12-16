module AssociationValidator
  extend ActiveSupport::Concern
  included do
    def self.validates_association_length_of(*args)
      args[1][:wrong_length] = 'should be of size %{count}'
      args[1][:too_long] = 'maximum size %{count} exceeded'
      args[1][:too_short] = 'under required minimum size %{count}'
      validates_with(Mongoid::Validatable::AssociationLengthValidator, _merge_attributes(args))
    end
  end
end
