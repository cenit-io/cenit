require 'imgkit'
require 'base64'

IMGKit.class_eval do
  def self.image_from_html(input_url, options = {})

    input_url = options[:url_encoded] ? Base64.decode64(input_url) : input_url

    image = new(input_url)
    case options[:output_format]
    when 'jpg'
      image.to_jpg
    when 'jpeg'
      image.to_jpeg
    when 'png'
      image.to_png
    end
  end
end
