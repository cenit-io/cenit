class AccountUploader < BasicUploader

  storage :account_grid_fs

  def grid
    self.class.grid
  end

  class << self

    attr_accessor :grid

  end
end
