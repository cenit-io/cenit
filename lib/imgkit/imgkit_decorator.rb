require 'imgkit'
require 'rmagick'

IMGKit.class_eval do
  def self.image_from_html(input_url, options = {})

    image = new(input_url)
    image_converted = ''

    case options[:output_format]
      when 'jpg'
        image_converted = image.to_jpg
      when 'jpeg'
        image_converted = image.to_jpeg
      when 'png'
        image_converted = image.to_png
    end

    if options[:logo]
      content_img = Magick::Image.from_blob(image_converted).first

      logo = Cenit.namespace(options[:namespace]).data_type('images').where(:filename => options[:logo]).first.data
      logo = Magick::Image.from_blob(logo) {
        self.format = 'PNG'
        self.background_color = 'White'
      }.first.resize(0.30).border(1, 1, 'white')

      background = Magick::Image.new(content_img.columns, logo.rows)

      marketing_img = background.composite(logo, Magick::CenterGravity, Magick::OverCompositeOp)
      image_temp = Tempfile.new('logo')
      marketing_img.write("#{options[:output_format]}:" + image_temp.path)
      image_temp.rewind

      image_list = Magick::ImageList.new
      image_list = image_list.from_blob(File.read(image_temp.path), content_img.to_blob) {
        self.format = options[:output_format]
        self.quality = 60}
      image_converted = image_list.append(true).to_blob
      image_temp.close
    end
    image_converted
  end
end
