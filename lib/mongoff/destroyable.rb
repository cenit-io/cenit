module Mongoff
  module Destroyable

    def destroy(options = {})
      begin
        orm_model.where(id: id).delete_one
      rescue
      end
      @destroyed = true
    end

  end
end