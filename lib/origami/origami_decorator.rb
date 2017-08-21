require 'openssl'
require 'origami'
include Origami

Origami.module_eval do
  self::PDF.class_eval do
    def to_blob
      output
    end

    def signature_page(page, options={})
      outer_leading = 10
      optimus_width = 180
      optimus_height = 22 * 3

      # Define the attributes of a box where we will put our annotation + mox stamp + description
      box = { x: page.MediaBox[2].to_f - optimus_width - outer_leading, y: outer_leading, width: optimus_width, height: optimus_height }

      contents = Origami::ContentStream.new

      # Load stamp avatar and add reference to the page
      if options[:annot_stamp][:avatar]
        stamp_avatar_options = {
          x: box[:x],
          y: box[:y] + 2.5,
          width: 60,
          height: 60
        }

        stamp_avatar = Origami::Graphics::ImageXObject.from_image_file(options[:annot_stamp][:avatar].tempfile.path)
        options[:annot_stamp][:avatar].tempfile.close!
        stamp_avatar.Width = stamp_avatar_options[:width]
        stamp_avatar.Height = stamp_avatar_options[:height]
        stamp_avatar.ColorSpace = Origami::Graphics::Color::Space::DEVICE_RGB
        stamp_avatar.BitsPerComponent = 8
        stamp_avatar.Interpolate = true
        page.add_xobject(:stamp_avatar, stamp_avatar)

        # Draw the image inside the box area
        contents.draw_image(:stamp_avatar, stamp_avatar_options)
      end

      # Write the description text inside the box area
      text = line = ''
      options[:annot].each_with_index do |value,|
        value[0] = value[0].capitalize.gsub('_', ' ')
        value[1] = Date.today.to_formatted_s(:rfc822) if value[1] == 'today'
        line = "#{value[0]}: #{value[1]}"
        text += "\n" if text != ''
        text += line
      end
      page.add_font(:TimesRoman, Origami::Font::Type1::Standard::TimesRoman.new.pre_build)
      write_box = { x: box[:x] + stamp_avatar_options[:width] + 5, y: stamp_avatar_options[:y] + stamp_avatar_options[:height] - 5 }
      contents.write(text, {
        :x => write_box[:x],
        :y => write_box[:y],
        :rendering => Origami::Text::Rendering::FILL,
        :size => 8,
        :leading => 8,
        :font => :TimesRoman,
        :stroke_color => Origami::ContentStream::DEFAULT_STROKE_COLOR
      })

      # Load stamp sign and add reference to the page
      if options[:annot_stamp][:sign]
        stamp_sign_options = {
          :x => write_box[:x],
          :y => stamp_avatar_options[:y],
          width: 50,
          height: 34
        }

        stamp_sign = Origami::Graphics::ImageXObject.from_image_file(options[:annot_stamp][:sign].tempfile.path)
        options[:annot_stamp][:sign].tempfile.close!
        stamp_sign.Width = stamp_sign_options[:width]
        stamp_sign.Height = stamp_sign_options[:height]
        stamp_sign.ColorSpace = Origami::Graphics::Color::Space::DEVICE_RGB
        stamp_sign.BitsPerComponent = 8
        stamp_sign.Interpolate = true
        page.add_xobject(:stamp_sign, stamp_sign)

        # Draw the image inside the box area
        contents.draw_image(:stamp_sign, stamp_sign_options)
      end

      # Set the contentstream with (stamp + text) as the contents of the page
      contents.draw_rectangle(box[:x], box[:y], box[:width], box[:height])
      page.setContents([page.Contents, contents])

      # Create the signature annotaion over the content area box
      annotation = Origami::Annotation::Widget::Signature.new
      annotation.Rect = Origami::Rectangle[
        :llx => box[:x],
        :lly => box[:y] + box[:height],
        :urx => box[:x] + box[:width],
        :ury => box[:y]
      ]

      # Add the signature annotation to the page
      page.add_annot(annotation)

      [page, annotation]
    end

  end

  def self.create_cert_and_keys(options={})
    if options[:RSAPrivateKey] and options[:PassPhrase] and options[:X509Certificate]
      key = OpenSSL::PKey::RSA.new options[:RSAPrivateKey], options[:PassPhrase]
      cert = OpenSSL::X509::Certificate.new options[:X509Certificate]
      return [cert, key]
    end

    key = OpenSSL::PKey::RSA.new 2048

    public_key = key.public_key

    c = options[:cert][:country] || 'CO'
    st = options[:cert][:estado] || 'Ciudad Habana'
    l = options[:cert][:locality] || 'Habana vieja'
    o = options[:cert][:organization] || 'Edificio Bacardi'
    ou = options[:cert][:organizational_unit] || 'OpenJAF'
    cn = options[:cert][:cn] || 'www.openjaf.com/emailAddress=openjaf@gmail.com'
    subject = "/C=#{c}/ST=#{st}/L=#{l}/O=#{o}/OU=#{ou}/CN=#{cn}"

    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
    cert.not_before = Time.now
    validity = options[:cert][:validity] || 1.year
    cert.not_after = Time.now + validity
    cert.public_key = public_key
    cert.serial = 0x0
    cert.version = 2

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.extensions = [
      ef.create_extension('basicConstraints', 'CA:TRUE', true),
      ef.create_extension('subjectKeyIdentifier', 'hash'),
    ]
    cert.add_extension ef.create_extension('authorityKeyIdentifier',
      'keyid:always,issuer:always')

    cert.sign key, OpenSSL::Digest::SHA256.new

    [cert, key]
  end

  def self.sign_pdf(input_pdf, options = {})
    self::PDF.convert_to_signable input_pdf.tempfile.path, input_pdf.tempfile.path

    cert, key = self.create_cert_and_keys(options)

    pdf = self::PDF.read(input_pdf.tempfile.path)
    original_filename = input_pdf.original_filename
    output_filename = original_filename.dup.insert(original_filename.rindex('.'), '_signed')
    input_pdf.tempfile.close!

    annotation = pdf.signature_page(pdf.pages.last, options)[1]

    # Sign the PDF with the specified keys
    pdf.sign(cert, key,
      :method => 'adbe.pkcs7.sha1',
      :annotation => annotation,
      :location => options[:cert][:location],
      :contact => options[:annot][:contact],
      :reason => options[:cert][:reason],
      :issuer => options[:cert][:issuer],
    )
    [pdf.to_blob, output_filename]
  end
end
