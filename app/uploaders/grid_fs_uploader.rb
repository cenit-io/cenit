class GridFsUploader < BasicUploader
  include GridFsFormatter

  storage :grid_fs
end