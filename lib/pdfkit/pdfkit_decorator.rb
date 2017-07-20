require 'pdfkit'
require 'tempfile'
require 'cenit/cenit'

PDFKit.class_eval do
  def self.pdf_from_html(url, options = {})
    header_html = Tempfile.new(%w(header .html))
    image = Cenit.namespace(options[:namespace]).data_type('images').where(:filename => 'appueste_logo.png').first
    image_temp = Tempfile.new(%w(appueste_logo .png), :encoding => 'ascii-8bit')
    image_temp.write(image.data)
    image_temp.rewind
    header_html.write(Cenit.namespace(options[:namespace]).translator('header_html').run(:path => image_temp.path))
    header_html.rewind

    footer_html = Tempfile.new(%w(footer .html))
    footer_html.write(Cenit.namespace(options[:namespace]).snippet('footer_html.html.erb').code)
    footer_html.rewind

    new(
        url,
        :header_html => header_html.path,
        :footer_html => footer_html.path,
        :margin_top => options[:margin_top],
        :margin_bottom => options[:margin_bottom],
        :margin_left => options[:margin_left],
        :margin_right => options[:margin_right],
    ).to_pdf
  end
end
