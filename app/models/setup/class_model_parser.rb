module Setup
  module ClassModelParser
    extend ActiveSupport::Concern

    module ClassMethods
      include InstanceModelParser
    end

  end
end
