module Hub
  class Base
    include Mongoid::Document
    include Mongoid::Timestamps
  
    include AccountScoped

  end  
end