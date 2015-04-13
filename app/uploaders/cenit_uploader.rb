class CenitUploader < BasicUploader

  storage :cenit_grid_fs

  def grid
    self.class.grid
  end

  class << self

    attr_accessor :grid

  end
end
