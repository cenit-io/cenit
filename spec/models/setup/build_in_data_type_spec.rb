require 'rails_helper'

describe Setup::BuildInDataType do

  let! :build_ins do
    Setup::BuildInDataType.build_ins.values
  end

  let! :models do
    build_ins.map(&:model)
  end

  context "for each build-in model" do
    it "responses to all its schema properties" do
      models.each do |model|
        properties = model.data_type.schema['properties']
        instance = model.new
        properties.keys.each do |property|
          expect(instance.respond_to?(property)).to be true
        end
      end
    end

    it "is a class hierarchy aware model if it has descendants" do
      super_models = Set.new(models)
      models.each do |model|
        descendants = model.descendants
        if descendants.empty?
          super_models.delete(model)
        else
          descendants.each do |sub_model|
            super_models.delete(sub_model)
          end
        end
      end
      super_models.each do |super_model|
        expect(super_model < Setup::ClassHierarchyAware).to be true
      end
    end
  end
end
