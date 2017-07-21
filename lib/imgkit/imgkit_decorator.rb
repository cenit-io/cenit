require 'imgkit'

IMGKit.class_eval do
  def self.image_from_html(input_url, options = {})

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
