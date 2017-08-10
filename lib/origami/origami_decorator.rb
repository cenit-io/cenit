require 'openssl'
require 'origami'
include Origami

Origami.module_eval do
  self::PDF.class_eval do
    def to_blob
      output
    end

    def signature_page(page, image_logo = nil, options={})

      # Define the attributes of a box where we will put our annotation + mox logo + description
      box = {x: 10, y: 10, width: 280, height: 20 * 3}

      # page = Origami::Page.new
      # contents = Origami::ContentStream.new page.Contents.rawdata.force_encoding('UTF-8'), page.Contents.dictionary
      contents = Origami::ContentStream.new

      # Load stamp and add reference to the page
      if image_logo
        stamp_options = {
            x: box[:x],
            y: box[:y],
            width: 60,
            height: 60
        }

        stamp = Origami::Graphics::ImageXObject.from_image_file(image_logo.tempfile.path)
        image_logo.tempfile.close!
        stamp.Width = stamp_options[:width]
        stamp.Height = stamp_options[:height]
        stamp.ColorSpace = Origami::Graphics::Color::Space::DEVICE_RGB
        stamp.BitsPerComponent = 8
        stamp.Interpolate = true
        page.add_xobject(:stamp, stamp)

        # Draw the image inside the box area
        contents.draw_image(:stamp, stamp_options)
      end

      # Write the description text inside the box area
      page.add_font(:TimesRoman, Origami::Font::Type1::Standard::TimesRoman.new.pre_build)
      contents.write("Signed at: #{Date.today.to_formatted_s(:rfc822)}\nSigned by: #{options[:Name]}\nEmail: #{options[:Contact]}", {
          :x => box[:x] + stamp_options[:width] + 5,
          :y => box[:y] + 40,
          :rendering => Origami::Text::Rendering::FILL,
          :size => 12,
          :leading => 15,
          :font => :TimesRoman,
          :stroke_color => Origami::ContentStream::DEFAULT_STROKE_COLOR,
          :line_width => Origami::ContentStream::DEFAULT_LINEWIDTH
      })
      contents.draw_rectangle(box[:x], box[:y], box[:width], box[:height])

      # Set the contentstream with (logo + text) as the contents of the page
      page.setContents([page.Contents, contents])

      # Create the signature annotaion over the content area box
      annotation = Origami::Annotation::Widget::Signature.new
      annotation.Rect = Origami::Rectangle[
          :llx => box[:x],
          :lly => box[:y],
          :urx => box[:x] + box[:width],
          :ury => box[:y] + box[:height]
      ]

      # Add the signature annotation to the page
      page.add_annot(annotation)

      [page, annotation]
    end

  end

  def self.sign_pdf(input_pdf, image_logo = nil, options = {})
    passphrase = options[:PassPhrase]
    key4pem = options[:RSAPrivateKey]

    key = OpenSSL::PKey::RSA.new key4pem, passphrase
    cert = OpenSSL::X509::Certificate.new options[:X509Certificate]

    pdf = self::PDF.read(input_pdf.tempfile.path)
    original_filename = input_pdf.original_filename
    output_filename = original_filename.dup.insert(original_filename.rindex('.'), '_signed')
    input_pdf.tempfile.close!

    # Add signature annotation (so it becomes visibles in pdf document)
    options[:Name] = 'Alain Fernandez Deroncere'
    annotation = pdf.signature_page(pdf.get_page(pdf.pages.length), image_logo, options)[1]

    # Sign the PDF with the specified keys
    pdf.sign(cert, key,
             :method => 'adbe.pkcs7.sha1',
             :annotation => annotation,
             :location => options[:Location],
             :contact => options[:Contact],
             :reason => options[:Reason]
    )
    [pdf.to_blob, output_filename]
  end
end
