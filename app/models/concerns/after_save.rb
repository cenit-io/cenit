module AfterSave
  extend ActiveSupport::Concern

  included do
    before_save do |object|
      @_obj_before = object.class.find(object.id) rescue @_obj_before = nil
    end

    after_save do |object|
      Setup::Event.lookup(self, @_obj_before);
    end
  end

  def data_type
    Setup::DataType.find_by(name: self.class.to_s)
  end
end