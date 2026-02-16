# Dependencies outside app/models/concerns/setup/
require 'csv'
require 'cgi'
require Rails.root.join('lib', 'mongoff', 'grid_fs', 'file_formatter.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'dynamic_validators.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'models.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'cenit', 'access.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'schema_handler.rb').to_s
puts "DEBUG: Setup::SchemaHandler defined? #{defined?(Setup::SchemaHandler)}"
require Rails.root.join('app', 'models', 'setup', 'data_type_parser.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'orm_model_aware.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'event_lookup.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'schema_model_aware.rb').to_s

require Rails.root.join('app', 'models', 'setup', 'build_in_data_type.rb').to_s







require Rails.root.join('app', 'models', 'concerns', 'setup', 'cenit_unscoped.rb').to_s
puts "DEBUG: Setup::CenitUnscoped defined? #{defined?(Setup::CenitUnscoped)}"
require Rails.root.join('app', 'models', 'concerns', 'account_scoped.rb').to_s
puts "DEBUG: AccountScoped defined? #{defined?(AccountScoped)}"
require Rails.root.join('app', 'models', 'concerns', 'setup', 'cenit_scoped.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'cross_origin', 'cenit_document.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'cross_origin_shared.rb').to_s




# Core Concerns (Dependencies)

require Rails.root.join('app', 'models', 'setup', 'custom_title.rb').to_s


require Rails.root.join('app', 'models', 'concerns', 'setup', 'namespace_named.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'class_hierarchy_aware.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'shared_editable.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'slug.rb').to_s

require Rails.root.join('app', 'models', 'concerns', 'setup', 'changed_if.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'model_configurable.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'build_in.rb').to_s


# Custom Validators
require Rails.root.join('lib', 'mongoid', 'validatable', 'non_blank_numericality_validator.rb').to_s



require Rails.root.join('app', 'models', 'concerns', 'setup', 'shared_configurable.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'data_type_config.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'data_type.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'bindings.rb').to_s
puts "DEBUG: Setup::Bindings defined? #{defined?(Setup::Bindings)}"

require Rails.root.join('app', 'models', 'concerns', 'setup', 'share_with_bindings.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'setup', 'hash_field.rb').to_s
puts "DEBUG: Setup::HashField defined? #{defined?(Setup::HashField)}"

require Rails.root.join('app', 'models', 'concerns', 'setup', 'json_metadata.rb').to_s

puts "DEBUG: Setup::JsonMetadata loaded"
require Rails.root.join('app', 'models', 'concerns', 'setup', 'authorization_handler.rb').to_s
puts "DEBUG: Setup::AuthorizationHandler loaded"
require Rails.root.join('app', 'models', 'setup', 'with_template_parameters.rb').to_s
puts "DEBUG: Setup::WithTemplateParameters loaded & defined? #{defined?(Setup::WithTemplateParameters)}"

require Rails.root.join('app', 'models', 'setup', 'with_source_options.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'fields_inspection.rb').to_s
puts "DEBUG: FieldsInspection defined? #{defined?(FieldsInspection)}"

require Rails.root.join('app', 'models', 'setup', 'parameter.rb').to_s
puts "DEBUG: Setup::Parameter defined? #{defined?(Setup::Parameter)}"

require Rails.root.join('app', 'models', 'concerns', 'number_generator.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'token_generator.rb').to_s
require Rails.root.join('app', 'models', 'concerns', 'credentials_generator.rb').to_s

require Rails.root.join('app', 'models', 'setup', 'connection_config.rb').to_s

require Rails.root.join('app', 'models', 'setup', 'validator.rb').to_s
puts "DEBUG: Setup::Validator defined? #{defined?(Setup::Validator)}"
require Rails.root.join('app', 'models', 'setup', 'custom_validator.rb').to_s

puts "DEBUG: Setup::CustomValidator defined? #{defined?(Setup::CustomValidator)}"
require Rails.root.join('app', 'models', 'setup', 'triggers_formatter.rb').to_s
puts "DEBUG: Setup::TriggersFormatter defined? #{defined?(Setup::TriggersFormatter)}"














require Rails.root.join('app', 'models', 'concerns', 'setup', 'snippet_code.rb').to_s

puts "DEBUG: Setup::SnippetCode defined? #{defined?(Setup::SnippetCode)}"

require Rails.root.join('app', 'models', 'setup', 'json_data_type.rb').to_s


require Rails.root.join('app', 'models', 'setup', 'format_validator.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'validator.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'snippet.rb').to_s

puts "DEBUG: Setup::Snippet defined? #{defined?(Setup::Snippet)}"





# Parsers & Handlers
require Rails.root.join('app', 'models', 'concerns', 'setup', 'class_model_parser.rb').to_s






puts "DEBUG: Setup::ClassHierarchyAware defined? #{defined?(Setup::ClassHierarchyAware)}"





require Rails.root.join('app', 'models', 'concerns', 'cenit', 'access.rb').to_s






require Rails.root.join('lib', 'mongoff', 'grid_fs', 'file_stuff.rb').to_s
require Rails.root.join('lib', 'edi', 'filler.rb').to_s

require Rails.root.join('app', 'models', 'setup', 'build_in.rb').to_s

require Rails.root.join('app', 'models', 'concerns', 'account_scoped.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'instance_model_parser.rb').to_s

# Topological sort for Setup concerns
requires = Dir.glob(Rails.root.join('app', 'models', 'concerns', 'setup', '*.rb')).map(&:to_s)
max_passes = 20
pass = 0

while requires.any? && pass < max_passes
  pass += 1
  failed = []
  requires.each do |f|
    begin
      require f
    rescue NameError, LoadError
      failed << f
    end
  end
  break if failed.empty? || failed.size == requires.size
  requires = failed
end

# Report failures (and potentially error out)
if requires.any?
  warn "DEBUG: Could not load the following files after #{pass} passes: #{requires.inspect}"
  requires.each do |f| 
    begin
      require f 
    rescue NameError, LoadError => e
      warn "DEBUG: Final attempt failed for #{f}: #{e.message}"
    end
  end
end

%w(
  namespace
  data_type
  schema
  webhook
  algorithm
  task
  authorization
  connection
  xslt_validator

  translator
  flow_config
  flow
  system_notification
  base_oauth_authorization
  oauth2_authorization
).each do |model|
  begin
    require Rails.root.join('app', 'models', 'setup', "#{model}.rb").to_s
  rescue LoadError
    warn "DEBUG: Could not load app/models/setup/#{model}.rb"
  end
end

resolve_constant = lambda do |name|
  name.to_s.split('::').inject(Object) { |scope, const_name| scope.const_get(const_name) }
rescue NameError
  nil
end

optional_capataz_constants = %w[
  Tenant
  MWS
  MWS::Orders::Client
  MWS::Feeds::Client
  Cenit::XMLRPC
].filter_map { |name| resolve_constant.call(name) }

account_tenant_models = %w[
  Account
  Tenant
].filter_map { |name| resolve_constant.call(name) }

Capataz.config do
  disable ENV['CAPATAZ_DISABLE']

  maximum_iterations ENV['CAPATAZ_MAXIMUM_ITERATIONS'] || 3000

  deny_declarations_of :module, :class, :self, :def, :const, :ivar, :cvar, :gvar

  deny_invoke_of :require, :new, :create, :class, :eval, :class_eval, :instance_eval, :instance_variable_set, :instance_variable_get, :constants, :const_get, :const_set, :constantize

  allow_invoke_of :nil?, :present?, :is_a?, :respond_to?, :try, '==', '!='

  allowed_constants Psych, JSON, URI, File, Array, Hash, Nokogiri, Nokogiri::XML, Nokogiri::XML::Builder, Time, Base64, Digest, Digest::MD5, Digest::SHA256,
                    SecureRandom, Setup, Setup::Namespace, Setup::DataType, Setup::Schema, OpenSSL, OpenSSL::PKey, OpenSSL::PKey::RSA,
                    OpenSSL::Digest, OpenSSL::Digest::SHA1, OpenSSL::HMAC, OpenSSL::X509::Certificate, Setup::Webhook, Setup::Algorithm,
                    Setup::Task, Setup::Task::RUNNING_STATUS, Setup::Task::NOT_RUNNING_STATUS, Setup::Task::ACTIVE_STATUS, Setup::Task::NON_ACTIVE_STATUS,
                    Xmldsig, Xmldsig::SignedDocument, Zip, Zip::OutputStream, Zip::InputStream, StringIO, MIME::Mail, MIME::Text, MIME::Multipart::Mixed,
                    Spreadsheet, Spreadsheet::Workbook, Setup::Authorization, Setup::Connection, Devise, Cenit, JWT, Setup::XsltValidator, Setup::Translator,
                    Setup::Flow, WriteXLSX, MIME::DiscreteMediaFactory, MIME::DiscreteMedia, MIME::DiscreteMedia, MIME::Image, MIME::Application, DateTime,
                    Setup::SystemNotification, Tempfile, *optional_capataz_constants,
                    Setup::Oauth2Authorization, CombinePDF, CSV, CGI


  # TODO Configure zip utility access when removing tangled access to Zip::[Output|Input]Stream
  # allow_on Zip, [:decode, :encode]
  #
  # allow_for Zip::Entry, [:name, :read]
  #

  allow_on CSV, [:parse, :generate]

  allow_on Setup::SystemNotification, :create_with

  if (cross_shared_collection = resolve_constant.call('Setup::CrossSharedCollection'))
    allow_for cross_shared_collection, [:pull, :shared?, :to_json, :share_json, :to_xml, :to_edi, :name]
  end

  allow_on account_tenant_models, [:find_where, :find_all, :switch, :notify, :data_type, :current] if account_tenant_models.any?

  allow_for account_tenant_models, [:id, :name, :key, :token, :notification_level, :switch, :get_owner, :owner, :errors] if account_tenant_models.any?

  allow_on Cenit, [:homepage, :namespace, :slack_link, :fail]

  allow_on JWT, [:encode, :decode]

  allow_on Devise, [:friendly_token]

  allow_on Spreadsheet::Workbook, [:new_workbook]

  allow_on MIME::Multipart::Mixed, [:new_message]

  allow_on MIME::Mail, [:new_message]

  allow_on MIME::Text, [:new_text]

  allow_on JSON, [:parse, :generate, :pretty_generate]

  allow_on Psych, [:load, :add_domain_type]

  allow_on YAML, [:load, :add_domain_type]

  allow_on URI, [:decode, :encode, :encode_www_form, :parse]

  allow_on CGI, [:escape, :unescape]

  allow_on StringIO, [:new_io]

  allow_on File, [:dirname, :basename]

  allow_on Time, [:strftime, :at, :year, :month, :day, :mday, :wday, :hour, :min, :sec, :now, :to_i, :utc, :getlocal, :gm, :gmtime, :local]

  allow_on DateTime, [:parse, :strftime, :strptime, :now]

  allow_on Xmldsig::SignedDocument, [:new_document, :sign]

  allow_on OpenSSL::PKey::RSA, [:new_rsa]

  allow_on OpenSSL::X509::Certificate, [:new_certificate]

  allow_on OpenSSL::Digest::SHA1, [:digest, :new_sha1]

  allow_for ActionView::Base, [
    # Form and form fields helpers
    :text_field, :password_field, :hidden_field, :file_field, :color_field, :search_field, :telephone_field,
    :phone_field, :date_field, :time_field, :datetime_field, :datetime_local_field, :month_field, :week_field,
    :url_field, :email_field, :number_field, :range_field,

    :text_field_tag, :hidden_field_tag, :file_field_tag, :password_field_tag, :color_field_tag, :search_field_tag,
    :telephone_field_tag, :phone_field_tag, :date_field_tag, :time_field_tag, :datetime_field_tag,
    :datetime_local_field_tag, :month_field_tag, :week_field_tag, :url_field_tag, :email_field_tag, :number_field_tag,
    :range_field_tag, :select_tag, :check_box_tag, :radio_button_tag, :submit_tag, :button_tag, :image_submit_tag,
    :form_tag, :text_area_tag, :utf8_enforcer_tag, :options_for_select,

    # Other html tags helpers
    :javascript_tag, :label_tag, :field_set_tag, :auto_discovery_link_tag, :favicon_link_tag, :image_tag, :video_tag,
    :audio_tag, :content_tag, :time_tag, :csrf_meta_tag,

    # Asset urls helpers
    :asset_url, :javascript_url, :stylesheet_url, :image_url, :video_url, :audio_url, :font_url,

    # Link tags helpers
    :stylesheet_link_tag, :link_to_previous_page, :link_to_next_page, :strip_links, :link_to, :link_to_if,
    :favicon_link_tag,

    # App control helpers
    :application, :namespace, :application_title, :url_for, :app_url, :render_template, :data_type, :data_file, :resource,
    :connection, :current_user, :current_account, :sign_in_url, :sign_out_url, :can?, :cannot?, :action, :flash_alert_class,
    :xhr?,

    # Other helpers
    :escape_javascript, :j, :content_for, :content_for?, :flash
  ]

  allow_on Setup::Task, [:current, :break, :where, :all]

  allow_on Setup::Task::RUNNING_STATUS, [:include?]

  allow_on Setup::Task::NOT_RUNNING_STATUS, [:include?]

  allow_on Setup::Task::ACTIVE_STATUS, [:include?]

  allow_on Setup::Task::NON_ACTIVE_STATUS, [:include?]

  allow_on Nokogiri::XML::Builder, [:with, :new_builder, :[]]

  allow_on Nokogiri::XML, [:search]

  allow_on Setup::Connection, Setup::Webhook.method_enum + [:webhook_for, :where, :del] - [:delete]

  allow_on Setup::Webhook, [:where]

  allow_on Setup::Translator, [:run, :where]

  allow_on WriteXLSX, [:new_xlsx]

  allow_on MIME::DiscreteMedia, [:create_media]

  allow_on MIME::Application, [:new_app]

  allow_on MIME::Image, [:new_img]

  allow_on MIME::DiscreteMedia, [:new_media]

  allow_on MIME::DiscreteMediaFactory, [:create_factory]

  if (mws_feeds_client = resolve_constant.call('MWS::Feeds::Client'))
    allow_on mws_feeds_client, [:new_feed]
  end

  if (magick_image = resolve_constant.call('Magick::Image'))
    allow_on magick_image, [:read]
  end

  allow_on Hash, Hash.methods

  allow_for [Mongoff::Model], [:where, :all, :data_type]

  # allow_for [Setup::Raml],  [:id, :name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model, :ref_hash, :raml_parse, :build_hash, :map_collection]

  allow_for [Class],
            [
              :where, :all, :now,
              :new_sign, :digest, :new_sha1, :hexdigest, :new_rsa, :sign, :new_certificate,
              :data_type, :id,
              :write_buffer, :put_next_entry, :write,
              :encode64, :decode64, :urlsafe_encode64, :new_io, :get_input_stream, :open, :new_document
            ] + Setup::Webhook.method_enum + [:del] - [:delete]

  allow_for [Mongoid::Criteria, Mongoff::Criteria], Enumerable.instance_methods(false) + Mongoid::Criteria::Queryable.instance_methods(false) + [:each, :blank?, :limit, :skip, :where, :distinct]

  allow_for Setup::Task, [:status, :scheduler, :schedule, :state, :resume_in, :run_again, :progress, :progress=, :update, :destroy, :notifications, :notify, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :id, :current_execution, :sources, :description, :agent, :join]

  if (setup_scheduler = resolve_constant.call('Setup::Scheduler'))
    allow_for setup_scheduler, [:activate, :activated?, :deactivate, :name, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :namespace]
  end

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
  end + [:name, :slug, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model, :namespace, :id, :ns_slug, :title, :where, :all, :build_indices] + Setup::DataType::RECORDS_MODEL_METHODS).flatten

  dynamic_record_models = [
    resolve_constant.call('Setup::DynamicRecord'),
    resolve_constant.call('Mongoff::Record')
  ].compact

  if dynamic_record_models.any?
    deny_for dynamic_record_models, ->(instance, method) do
      return false if [:id, :to_json, :share_json, :to_edi, :to_hash, :to_xml, :to_xml_element, :to_params, :from_json, :from_xml, :from_edi, :[], :[]=, :save, :save!, :all, :where, :orm_model, :==, :errors, :destroy, :new_record?].include?(method)
      return false if instance.orm_model.data_type.records_methods.any? { |alg| alg.name == method.to_s }
      return false if [:data].include?(method) && instance.is_a?(Mongoff::GridFs::FileFormatter)
      if (method = method.to_s).end_with?('=')
        method = method.chop
      end
      instance.orm_model.property_schema(method).nil?
    end
  end

  if (cenit_control = resolve_constant.call('Cenit::Control'))
    deny_for cenit_control, [:model_adapter, :controller, :view]
  end

  if (user_model = resolve_constant.call('User'))
    allow_for user_model, [:id, :short_name, :name, :given_name, :family_name, :picture_url, :number, :email, :sign_in_count, :created_at, :updated_at, :current_sign_in_ip, :last_sign_in_ip, :has_role?, :account, :accounts]
    allow_on user_model, [:find_where, :find_all, :current]
  end

  allow_on CombinePDF, [:new_pdf]
end
