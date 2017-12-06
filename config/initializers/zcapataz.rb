Capataz.config do

  disable ENV['CAPATAZ_DISABLE']

  maximum_iterations ENV['CAPATAZ_MAXIMUM_ITERATIONS'] || 3000

  deny_declarations_of :module, :class, :yield, :self, :def, :const, :ivar, :cvar, :gvar, :return

  deny_invoke_of :require, :new, :create, :class, :eval, :class_eval, :instance_eval, :instance_variable_set, :instance_variable_get, :constants, :const_get, :const_set, :constantize

  allowed_constants Psych, JSON, URI, File, Array, Hash, Nokogiri, Nokogiri::XML, Nokogiri::XML::Builder, Time, Base64, Digest, Digest::MD5, Digest::SHA256,
    SecureRandom, Setup, Setup::Namespace, Setup::DataType, Setup::Schema, OpenSSL, OpenSSL::PKey, OpenSSL::PKey::RSA,
    OpenSSL::Digest, OpenSSL::Digest::SHA1, OpenSSL::HMAC, OpenSSL::X509::Certificate, Setup::Webhook, Setup::Algorithm,
    Setup::Task, Setup::Task::RUNNING_STATUS, Setup::Task::NOT_RUNNING_STATUS, Setup::Task::ACTIVE_STATUS, Setup::Task::NON_ACTIVE_STATUS,
    Xmldsig, Xmldsig::SignedDocument, Zip, Zip::OutputStream, Zip::InputStream, StringIO, MIME::Mail, MIME::Text, MIME::Multipart::Mixed,
    Spreadsheet, Spreadsheet::Workbook, Setup::Authorization, Setup::Connection, Devise, Cenit, JWT, Setup::XsltValidator, Setup::Translator,
    Setup::Flow, WriteXLSX, MIME::DiscreteMediaFactory, MIME::DiscreteMedia, MIME::DiscreteMedia, MIME::Image, MIME::Application, DateTime,
    Tenant, Setup::SystemNotification, WickedPdf, Magick::Image, PDFKit, Tempfile, IMGKit, Origami, PdfForms, CombinePDF

  # TODO Configure zip utility access when removing tangled access to Zip::[Output|Input]Stream
  # allow_on Zip, [:decode, :encode]
  #
  # allow_for Zip::Entry, [:name, :read]

  allow_on Setup::SystemNotification, :create_with

  allow_for Setup::CrossSharedCollection, [:pull, :shared?, :to_json, :share_json, :to_xml, :to_edi]

  allow_on [Account, Tenant], [:name, :where, :all, :switch, :notify]

  allow_on Cenit, [:homepage, :namespace]

  allow_on JWT, [:encode, :decode]

  allow_on Devise, [:friendly_token]

  allow_on Spreadsheet::Workbook, [:new_workbook]

  allow_on MIME::Multipart::Mixed, [:new_message]

  allow_on MIME::Mail, [:new_message]

  allow_on MIME::Text, [:new_text]

  allow_on JSON, [:parse, :pretty_generate]

  allow_on Psych, [:load, :add_domain_type]

  allow_on YAML, [:load, :add_domain_type]

  allow_on URI, [:decode, :encode, :encode_www_form, :parse]

  allow_on StringIO, [:new_io]

  allow_on File, [:dirname, :basename]

  allow_on Time, [:strftime, :at, :year, :month, :day, :mday, :wday, :hour, :min, :sec, :now, :to_i, :utc, :getlocal, :gm, :gmtime, :local]

  allow_on DateTime, [:parse, :strftime]

  allow_on Xmldsig::SignedDocument, [:new_document, :sign]

  allow_on OpenSSL::PKey::RSA, [:new_rsa]

  allow_on OpenSSL::X509::Certificate, [:new_certificate]

  allow_on OpenSSL::Digest::SHA1, [:digest, :new_sha1]

  allow_for ActionView::Base, [:escape_javascript, :j]

  allow_on Setup::Task, [:current, :where, :all]

  allow_on Setup::Task::RUNNING_STATUS, [:include?]

  allow_on Setup::Task::NOT_RUNNING_STATUS, [:include?]

  allow_on Setup::Task::ACTIVE_STATUS, [:include?]

  allow_on Setup::Task::NON_ACTIVE_STATUS, [:include?]

  allow_on Nokogiri::XML::Builder, [:with, :new_builder, :[]]

  allow_on Nokogiri::XML, [:search]

  allow_on Setup::Connection, Setup::Webhook.method_enum + [:webhook_for, :where]

  allow_on Setup::Webhook, [:where]

  allow_on Setup::Translator, [:run, :where]

  allow_on WriteXLSX, [:new_xlsx]

  allow_on MIME::DiscreteMedia, [:create_media]

  allow_on MIME::Application, [:new_app]

  allow_on MIME::Image, [:new_img]

  allow_on MIME::DiscreteMedia, [:new_media]

  allow_on MIME::DiscreteMediaFactory, [:create_factory]

  allow_on PDFKit, [:pdf_from_html]

  allow_on IMGKit, [:image_from_html]

  allow_on Origami, [:sign_pdf]

  allow_on WickedPdf, [:new_wickedpdf]

  allow_on Magick::Image, [:read]

  allow_for [Mongoff::Model], [:where, :all, :data_type]

  # allow_for [Setup::Raml],  [:id, :name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model, :ref_hash, :raml_parse, :build_hash, :map_collection]

  allow_for [Class],
    [
      :where, :all, :now,
      :new_sign, :digest, :new_sha1, :hexdigest, :new_rsa, :sign, :new_certificate,
      :data_type, :id,
      :write_buffer, :put_next_entry, :write,
      :encode64, :decode64, :urlsafe_encode64, :new_io, :get_input_stream, :open, :new_document
    ] + Setup::Webhook.method_enum

  allow_for [Mongoid::Criteria, Mongoff::Criteria], Enumerable.instance_methods(false) + Origin::Queryable.instance_methods(false) + [:each, :present?, :blank?, :limit, :skip]

  allow_for Setup::Task, [:status, :scheduler, :state, :resume_in, :run_again, :progress, :progress=, :update, :destroy, :notifications, :notify, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :id, :current_execution, :sources, :description]

  allow_for Setup::Scheduler, [:activated?, :name, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :namespace]

  allow_for Setup::Webhook::HttpResponse, [:code, :body, :headers, :content_type]

  allow_for Setup::Webhook::Response, [:code, :body, :headers, :content_type]

  allow_for Setup::DataType, ((%w(_json _xml _edi) + ['']).collect do |format|
    %w(create new create!).collect do |action|
      if action.end_with?('!')
        "#{action.chop}_from#{format}!"
      else
        "#{action}_from#{format}"
      end
    end + [:create_from]
  end + [:name, :slug, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model, :namespace, :id, :ns_slug, :nil?, :title] + Setup::DataType::RECORDS_MODEL_METHODS).flatten

  deny_for [Setup::DynamicRecord, Mongoff::Record], ->(instance, method) do
    return false if [:id, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :to_xml_element, :to_params, :from_json, :from_xml, :from_edi, :[], :[]=, :save, :all, :where, :orm_model, :nil?, :==, :errors, :destroy, :new_record?].include?(method)
    return false if instance.orm_model.data_type.records_methods.any? { |alg| alg.name == method.to_s }
    return false if [:data].include?(method) && instance.is_a?(Mongoff::GridFs::FileFormatter)
    if (method = method.to_s).end_with?('=')
      method = method.chop
    end
    instance.orm_model.property_schema(method).nil?
  end

  allow_on PdfForms, [:new_pdfform, :to_pdf_data, :save_to, :get_field_names, :fill_form]
  allow_on PdfForms::Fdf, [:new_pdf]
  allow_on CombinePDF, [:new_pdf]
end
