require 'imgkit'

IMGKit.configure do |config|
  config.wkhtmltoimage = '/usr/bin/wkhtmltoimage'
  config.default_format = :jpg
  config.default_options = {
      :quality => 60
  }
end
