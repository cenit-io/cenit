require 'imgkit'
IMGKit.class_eval do
  def self.image_from_html(url, options = {})
    image = new(url)
    case options[:format]
    when 'jpg'
      image.to_jpg
    when 'jpeg'
      image.to_jpeg
    when 'png'
      image.to_png
    end
  end
end
