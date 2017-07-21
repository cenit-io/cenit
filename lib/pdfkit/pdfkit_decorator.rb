require 'pdfkit'
require 'tempfile'
require 'cenit/cenit'

PDFKit.class_eval do
  def self.pdf_from_html(input_url, options = {})
    header_html = Tempfile.new(%w(header .html))
    if options[:logo]
      image = Cenit.namespace(options[:namespace]).data_type('images').where(:filename => options[:logo]).first
      image_temp = Tempfile.new(%w(logo .png), :encoding => 'ascii-8bit')
      image_temp.write(image.data)
      image_temp.rewind
      header_html.write(Cenit.namespace(options[:namespace]).translator('header_html').run(:path => image_temp.path))
      image_temp.close
    else
      header_html.write(Cenit.namespace(options[:namespace]).snippet('header_html.html.erb').code)
    end
    header_html.rewind

    footer_html = Tempfile.new(%w(footer .html))
    footer_html.write(Cenit.namespace(options[:namespace]).snippet('footer_html.html.erb').code)
    footer_html.rewind

    pdf = new(
        input_url,
        :header_html => header_html.path,
        :footer_html => footer_html.path,
        :margin_top => options[:margin_top],
        :margin_bottom => options[:margin_bottom],
        :margin_left => options[:margin_left],
        :margin_right => options[:margin_right],
    ).to_pdf

    header_html.close
    footer_html.close

    pdf
  end
end
